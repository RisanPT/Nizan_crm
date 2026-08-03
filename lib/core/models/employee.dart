class Employee {
  final String id;
  final String name;
  final String email;
  final String type;
  final String artistRole;
  final String specialization;
  final List<String> works;
  final String phone;
  final String status;
  final String regionId;
  final String regionName;
  final String zoneId;
  final String zoneName;
  final String stateId;
  final String stateName;
  final String districtId;
  final String districtName;
  final String pincodeId;
  final String pincodeCode;
  final String category;
  final String profileImage;
  final String? department;
  final String? role;
  final String salaryType;
  final double baseSalary;
  final double allowances;
  final double deductions;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String upiId;
  final String panNumber;

  const Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.type,
    required this.artistRole,
    required this.specialization,
    this.works = const [],
    required this.phone,
    required this.status,
    required this.regionId,
    required this.regionName,
    this.zoneId = '',
    this.zoneName = '',
    this.stateId = '',
    this.stateName = '',
    this.districtId = '',
    this.districtName = '',
    this.pincodeId = '',
    this.pincodeCode = '',
    required this.category,
    this.profileImage = '',
    this.department,
    this.role,
    this.salaryType = 'fixed_monthly',
    this.baseSalary = 0,
    this.allowances = 0,
    this.deductions = 0,
    this.bankName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.upiId = '',
    this.panNumber = '',
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    final region = json['regionId'];
    final zone = json['zoneId'];
    final state = json['stateId'];
    final district = json['districtId'];
    final pincode = json['pincodeId'];

    return Employee(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      type: json['type'] as String? ?? 'outsource',
      artistRole: json['artistRole'] as String? ?? 'artist',
      specialization: json['specialization'] as String? ?? '',
      works: ((json['works'] as List?) ?? const [])
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(),
      phone: json['phone'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      regionId: region is Map<String, dynamic>
          ? (region['_id'] as String? ?? '')
          : (json['regionId'] as String? ?? ''),
      regionName: region is Map<String, dynamic>
          ? (region['name'] as String? ?? '')
          : '',
      zoneId: zone is Map<String, dynamic>
          ? (zone['_id'] as String? ?? '')
          : (json['zoneId'] as String? ?? ''),
      zoneName: zone is Map<String, dynamic>
          ? (zone['name'] as String? ?? '')
          : '',
      stateId: state is Map<String, dynamic>
          ? (state['_id'] as String? ?? '')
          : (json['stateId'] as String? ?? ''),
      stateName: state is Map<String, dynamic>
          ? (state['name'] as String? ?? '')
          : '',
      districtId: district is Map<String, dynamic>
          ? (district['_id'] as String? ?? '')
          : (json['districtId'] as String? ?? ''),
      districtName: district is Map<String, dynamic>
          ? (district['name'] as String? ?? '')
          : '',
      pincodeId: pincode is Map<String, dynamic>
          ? (pincode['_id'] as String? ?? '')
          : (json['pincodeId'] as String? ?? ''),
      pincodeCode: pincode is Map<String, dynamic>
          ? (pincode['code'] as String? ?? '')
          : '',
      category: json['category'] as String? ?? 'creative',
      profileImage: json['profileImage'] as String? ?? '',
      department: json['department'] as String?,
      role: json['role'] as String?,
      salaryType: json['salaryType'] as String? ?? 'fixed_monthly',
      baseSalary: (json['baseSalary'] as num?)?.toDouble() ?? 0,
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0,
      bankName: json['bankName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      ifscCode: json['ifscCode'] as String? ?? '',
      upiId: json['upiId'] as String? ?? '',
      panNumber: json['panNumber'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'type': type,
      'artistRole': artistRole,
      'specialization': specialization,
      'works': works,
      'phone': phone,
      'status': status,
      'regionId': regionId,
      'zoneId': zoneId,
      'stateId': stateId,
      'districtId': districtId,
      'pincodeId': pincodeId,
      'category': category,
      'profileImage': profileImage,
      if (department != null) 'department': department,
      if (role != null) 'role': role,
      'salaryType': salaryType,
      'baseSalary': baseSalary,
      'allowances': allowances,
      'deductions': deductions,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'upiId': upiId,
      'panNumber': panNumber,
    };
  }
}
