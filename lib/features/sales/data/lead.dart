class Lead {
  final String id;
  final String name;
  final String? email;
  final String phone;
  final String source;
  final String location;
  final String leadType;
  /// Event Type (Wedding, Reception, …) — replaces the old Lead Type in the UI.
  final String eventType;
  /// Optional secondary contact number.
  final String alternateNumber;
  final DateTime leadDate; // manually set: actual date lead was received
  final DateTime enquiryDate;
  final DateTime? bookedDate;
  final DateTime? followUpDate; // date+time for follow-up reminder
  /// How many times a follow-up has been scheduled for this lead.
  final int followUpCount;
  final String? assignedTo; // ID of the assigned salesman user
  final String status;

  /// How likely the lead is to close: Hot / Warm / Cold. Tracked separately
  /// from [status] so a lead can be e.g. "Follow-up" and "Hot" at once.
  final String priority;

  /// Set when a booking exists for this lead's phone number.
  final String? bookingId;

  /// Geography copied from the booking once the lead converts.
  final String address;
  final String pincode;
  final String district;
  final String region;
  final String reason;
  final String remarks;
  /// Lost-approval workflow.
  final String competitorName;
  final String lostAttachment;
  final String lostDecision; // '', 'approved', 'rejected'
  final String lostReviewNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  Lead({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    required this.source,
    required this.location,
    required this.leadType,
    this.eventType = '',
    this.alternateNumber = '',
    required this.leadDate,
    required this.enquiryDate,
    this.bookedDate,
    this.followUpDate,
    this.followUpCount = 0,
    this.assignedTo,
    required this.status,
    this.priority = 'Warm',
    this.bookingId,
    this.address = '',
    this.pincode = '',
    this.district = '',
    this.region = '',
    required this.reason,
    required this.remarks,
    this.competitorName = '',
    this.lostAttachment = '',
    this.lostDecision = '',
    this.lostReviewNote = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String).toLocal()
        : DateTime.now();
    return Lead(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String? ?? '',
      source: json['source'] as String? ?? 'Walk-in',
      location: json['location'] as String? ?? '',
      leadType: json['leadType'] as String? ?? 'Individual',
      eventType: json['eventType'] as String? ?? '',
      alternateNumber: json['alternateNumber'] as String? ?? '',
      // leadDate: manually set received date, fallback to createdAt
      leadDate: json['leadDate'] != null
          ? DateTime.parse(json['leadDate'] as String).toLocal()
          : createdAt,
      enquiryDate: json['enquiryDate'] != null
          ? DateTime.parse(json['enquiryDate'] as String).toLocal()
          : DateTime.now(),
      bookedDate: json['bookedDate'] != null
          ? DateTime.parse(json['bookedDate'] as String).toLocal()
          : null,
      followUpDate: json['followUpDate'] != null
          ? DateTime.parse(json['followUpDate'] as String).toLocal()
          : null,
      followUpCount: (json['followUpCount'] as num?)?.toInt() ?? 0,
      assignedTo: json['assignedTo'] is Map
          ? json['assignedTo']['_id'] as String?
          : json['assignedTo'] as String?,
      status: json['status'] as String? ?? 'New',
      priority: json['priority'] as String? ?? 'Warm',
      bookingId: json['bookingId'] is Map
          ? json['bookingId']['_id'] as String?
          : json['bookingId'] as String?,
      address: json['address'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      district: json['district'] as String? ?? '',
      region: json['region'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      competitorName: json['competitorName'] as String? ?? '',
      lostAttachment: json['lostAttachment'] as String? ?? '',
      lostDecision: json['lostDecision'] as String? ?? '',
      lostReviewNote: json['lostReviewNote'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'source': source,
      'location': location,
      'leadType': leadType,
      'eventType': eventType,
      'alternateNumber': alternateNumber,
      'leadDate': leadDate.toIso8601String(),
      'enquiryDate': enquiryDate.toIso8601String(),
      if (bookedDate != null) 'bookedDate': bookedDate?.toIso8601String(),
      if (followUpDate != null) 'followUpDate': followUpDate?.toIso8601String(),
      if (assignedTo != null) 'assignedTo': assignedTo,
      'status': status,
      'priority': priority,
      'reason': reason,
      'remarks': remarks,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Lead copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? source,
    String? location,
    String? leadType,
    String? eventType,
    String? alternateNumber,
    DateTime? leadDate,
    DateTime? enquiryDate,
    DateTime? bookedDate,
    DateTime? followUpDate,
    int? followUpCount,
    String? assignedTo,
    String? status,
    String? priority,
    String? reason,
    String? remarks,
    String? competitorName,
    String? lostAttachment,
    String? lostDecision,
    String? lostReviewNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lead(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      source: source ?? this.source,
      location: location ?? this.location,
      leadType: leadType ?? this.leadType,
      eventType: eventType ?? this.eventType,
      alternateNumber: alternateNumber ?? this.alternateNumber,
      leadDate: leadDate ?? this.leadDate,
      enquiryDate: enquiryDate ?? this.enquiryDate,
      bookedDate: bookedDate ?? this.bookedDate,
      followUpDate: followUpDate ?? this.followUpDate,
      followUpCount: followUpCount ?? this.followUpCount,
      assignedTo: assignedTo ?? this.assignedTo,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      reason: reason ?? this.reason,
      remarks: remarks ?? this.remarks,
      competitorName: competitorName ?? this.competitorName,
      lostAttachment: lostAttachment ?? this.lostAttachment,
      lostDecision: lostDecision ?? this.lostDecision,
      lostReviewNote: lostReviewNote ?? this.lostReviewNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
