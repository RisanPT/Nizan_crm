class Lead {
  final String id;
  final String name;
  final String? email;
  final String phone;
  final String source;
  final String location;
  final String leadType;
  final DateTime enquiryDate;
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
    required this.status,
    required this.reason,
    required this.remarks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String? ?? '',
      source: json['source'] as String? ?? 'Walk-in',
      location: json['location'] as String? ?? '',
      leadType: json['leadType'] as String? ?? 'Individual',
      enquiryDate: json['enquiryDate'] != null
          ? DateTime.parse(json['enquiryDate'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'New',
      reason: json['reason'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'source': source,
      'location': location,
      'leadType': leadType,
      'enquiryDate': enquiryDate.toIso8601String(),
      'status': status,
      'reason': reason,
      'remarks': remarks,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
