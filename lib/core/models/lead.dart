class Lead {
  final String id;
  final String name;
  final String? email;
  final String phone;
  final String source;
  final String location;
  final String leadType;
  final DateTime enquiryDate;
  final DateTime? bookedDate;
  final String status;
  final String reason;
  final String remarks;
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
    required this.enquiryDate,
    this.bookedDate,
    required this.status,
    required this.reason,
    required this.remarks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String? ?? '',
      source: json['source'] as String? ?? 'Walk-in',
      location: json['location'] as String? ?? '',
      leadType: json['leadType'] as String? ?? 'Individual',
      enquiryDate: json['enquiryDate'] != null
          ? DateTime.parse(json['enquiryDate'] as String).toLocal()
          : DateTime.now(),
      bookedDate: json['bookedDate'] != null
          ? DateTime.parse(json['bookedDate'] as String).toLocal()
          : null,
      status: json['status'] as String? ?? 'New',
      reason: json['reason'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
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
      'enquiryDate': enquiryDate.toIso8601String(),
      if (bookedDate != null) 'bookedDate': bookedDate?.toIso8601String(),
      'status': status,
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
    DateTime? enquiryDate,
    DateTime? bookedDate,
    String? status,
    String? reason,
    String? remarks,
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
      enquiryDate: enquiryDate ?? this.enquiryDate,
      bookedDate: bookedDate ?? this.bookedDate,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
