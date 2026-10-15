class Employee {
  final String id;
  final String employeeCode;
  final String name;
  final String email;
  final String type;
  final String artistRole;
  final String specialization;
  final List<String> works;
  final String phone;
  final String status;
  final String employmentStatus; // 'probation', 'confirmed', 'notice_period', 'exited'
  final DateTime? dateOfBirth;
  final DateTime? dateOfJoining;
  final DateTime? probationEndDate;
  final String emergencyContactName;
  final String emergencyContactRelation;
  final String emergencyContactPhone;
  final String currentGrade; // 'A', 'B', 'C', 'D'
  final double overtimeRate;
  final bool epfApplicable;
  final bool esiApplicable;
  final String uan;
  final String esiNumber;
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
  // Monthly House Rent Allowance configured for this employee. Paid via the
  // separate HRA screen (Accounts) — NOT bundled into the salary slip.
  final double hra;
  // Recurring day-of-month (1–31) the HRA is due; auto-fills the HRA screen date.
  // 0 = not set.
  final int hraDay;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String upiId;
  final String panNumber;
  final String? departmentId;
  final String? reportingManagerId;
  final String? designationId;
  final int? timeboxEmployeeId;
  final String timeboxName;

  const Employee({
    required this.id,
    this.employeeCode = '',
    required this.name,
    required this.email,
    required this.type,
    required this.artistRole,
    required this.specialization,
    this.works = const [],
    required this.phone,
    required this.status,
    this.employmentStatus = 'probation',
    this.dateOfBirth,
    this.dateOfJoining,
    this.probationEndDate,
    this.emergencyContactName = '',
    this.emergencyContactRelation = '',
    this.emergencyContactPhone = '',
    this.currentGrade = 'B',
    this.overtimeRate = 0.0,
    this.epfApplicable = false,
    this.esiApplicable = false,
    this.uan = '',
    this.esiNumber = '',
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
    this.departmentId,
    this.role,
    this.reportingManagerId,
    this.designationId,
    this.salaryType = 'fixed_monthly',
    this.baseSalary = 0,
    this.allowances = 0,
    this.deductions = 0,
    this.hra = 0,
    this.hraDay = 0,
    this.bankName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.upiId = '',
    this.panNumber = '',
    this.timeboxEmployeeId,
    this.timeboxName = '',
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    final region = json['regionId'];
    final zone = json['zoneId'];
    final state = json['stateId'];
    final district = json['districtId'];
    final pincode = json['pincodeId'];

    final ec = json['emergencyContact'];
    final ecName = ec is Map ? (ec['name']?.toString() ?? '') : '';
    final ecRel = ec is Map ? (ec['relation']?.toString() ?? '') : '';
    final ecPhone = ec is Map ? (ec['phone']?.toString() ?? '') : '';

    final stat = json['statutoryApplicability'];
    final epf = stat is Map ? (stat['epf'] == true) : false;
    final esi = stat is Map ? (stat['esi'] == true) : false;
    final uanVal = stat is Map ? (stat['uan']?.toString() ?? '') : '';
    final esiNum = stat is Map ? (stat['esiNumber']?.toString() ?? '') : '';

    return Employee(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      employeeCode: json['employeeCode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      type: json['type'] as String? ?? 'in-house',
      artistRole: json['artistRole'] as String? ?? 'artist',
      specialization: json['specialization'] as String? ?? '',
      works: ((json['works'] as List?) ?? const [])
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(),
      phone: json['phone'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      employmentStatus: json['employmentStatus'] as String? ?? 'probation',
      dateOfBirth: json['dateOfBirth'] != null ? DateTime.tryParse(json['dateOfBirth'].toString()) : null,
      dateOfJoining: json['dateOfJoining'] != null ? DateTime.tryParse(json['dateOfJoining'].toString()) : null,
      probationEndDate: json['probationEndDate'] != null ? DateTime.tryParse(json['probationEndDate'].toString()) : null,
      emergencyContactName: ecName,
      emergencyContactRelation: ecRel,
      emergencyContactPhone: ecPhone,
      currentGrade: json['currentGrade'] as String? ?? 'B',
      overtimeRate: (json['overtimeRate'] as num?)?.toDouble() ?? 0.0,
      epfApplicable: epf,
      esiApplicable: esi,
      uan: uanVal,
      esiNumber: esiNum,
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
      departmentId: json['departmentId'] is Map
          ? (json['departmentId']['_id'] as String?)
          : (json['departmentId'] as String?),
      role: json['role'] as String?,
      reportingManagerId: json['reportingManagerId'] is Map
          ? (json['reportingManagerId']['_id'] as String?)
          : (json['reportingManagerId'] as String?),
      designationId: json['designationId'] is Map
          ? (json['designationId']['_id'] as String?)
          : (json['designationId'] as String?),
      salaryType: json['salaryType'] as String? ?? 'fixed_monthly',
      baseSalary: (json['baseSalary'] as num?)?.toDouble() ?? 0,
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0,
      hra: (json['hra'] as num?)?.toDouble() ?? 0,
      hraDay: (json['hraDay'] as num?)?.toInt() ?? 0,
      bankName: json['bankName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      ifscCode: json['ifscCode'] as String? ?? '',
      upiId: json['upiId'] as String? ?? '',
      panNumber: json['panNumber'] as String? ?? '',
      timeboxEmployeeId: (json['timeboxEmployeeId'] as num?)?.toInt(),
      timeboxName: json['timeboxName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (employeeCode.isNotEmpty) 'employeeCode': employeeCode,
      'name': name,
      'email': email,
      'type': type,
      'artistRole': artistRole,
      'specialization': specialization,
      'works': works,
      'phone': phone,
      'status': status,
      'employmentStatus': employmentStatus,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
      if (dateOfJoining != null) 'dateOfJoining': dateOfJoining!.toIso8601String(),
      if (probationEndDate != null) 'probationEndDate': probationEndDate!.toIso8601String(),
      'emergencyContact': {
        'name': emergencyContactName,
        'relation': emergencyContactRelation,
        'phone': emergencyContactPhone,
      },
      'currentGrade': currentGrade,
      'overtimeRate': overtimeRate,
      'statutoryApplicability': {
        'epf': epfApplicable,
        'esi': esiApplicable,
        'uan': uan,
        'esiNumber': esiNumber,
      },
      'regionId': regionId,
      'zoneId': zoneId,
      'stateId': stateId,
      'districtId': districtId,
      'pincodeId': pincodeId,
      'category': category,
      'profileImage': profileImage,
      if (department != null) 'department': department,
      if (departmentId != null && departmentId!.isNotEmpty) 'departmentId': departmentId,
      if (role != null) 'role': role,
      if (reportingManagerId != null && reportingManagerId!.isNotEmpty) 'reportingManagerId': reportingManagerId,
      if (designationId != null && designationId!.isNotEmpty) 'designationId': designationId,
      'salaryType': salaryType,
      'baseSalary': baseSalary,
      'allowances': allowances,
      'deductions': deductions,
      'hra': hra,
      'hraDay': hraDay,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'upiId': upiId,
      'panNumber': panNumber,
      if (timeboxEmployeeId != null) 'timeboxEmployeeId': timeboxEmployeeId,
      if (timeboxName.isNotEmpty) 'timeboxName': timeboxName,
    };
  }

  bool get isTimeboxLinked => timeboxEmployeeId != null;

  Employee copyWith({
    String? id,
    String? employeeCode,
    String? name,
    String? email,
    String? type,
    String? artistRole,
    String? specialization,
    List<String>? works,
    String? phone,
    String? status,
    String? employmentStatus,
    DateTime? dateOfBirth,
    DateTime? dateOfJoining,
    DateTime? probationEndDate,
    String? emergencyContactName,
    String? emergencyContactRelation,
    String? emergencyContactPhone,
    String? currentGrade,
    double? overtimeRate,
    bool? epfApplicable,
    bool? esiApplicable,
    String? uan,
    String? esiNumber,
    String? regionId,
    String? regionName,
    String? zoneId,
    String? zoneName,
    String? stateId,
    String? stateName,
    String? districtId,
    String? districtName,
    String? pincodeId,
    String? pincodeCode,
    String? category,
    String? profileImage,
    String? department,
    String? departmentId,
    String? role,
    String? reportingManagerId,
    String? designationId,
    String? salaryType,
    double? baseSalary,
    double? allowances,
    double? deductions,
    double? hra,
    int? hraDay,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
    String? panNumber,
    int? timeboxEmployeeId,
    String? timeboxName,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      name: name ?? this.name,
      email: email ?? this.email,
      type: type ?? this.type,
      artistRole: artistRole ?? this.artistRole,
      specialization: specialization ?? this.specialization,
      works: works ?? this.works,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      dateOfJoining: dateOfJoining ?? this.dateOfJoining,
      probationEndDate: probationEndDate ?? this.probationEndDate,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      currentGrade: currentGrade ?? this.currentGrade,
      overtimeRate: overtimeRate ?? this.overtimeRate,
      epfApplicable: epfApplicable ?? this.epfApplicable,
      esiApplicable: esiApplicable ?? this.esiApplicable,
      uan: uan ?? this.uan,
      esiNumber: esiNumber ?? this.esiNumber,
      regionId: regionId ?? this.regionId,
      regionName: regionName ?? this.regionName,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      stateId: stateId ?? this.stateId,
      stateName: stateName ?? this.stateName,
      districtId: districtId ?? this.districtId,
      districtName: districtName ?? this.districtName,
      pincodeId: pincodeId ?? this.pincodeId,
      pincodeCode: pincodeCode ?? this.pincodeCode,
      category: category ?? this.category,
      profileImage: profileImage ?? this.profileImage,
      department: department ?? this.department,
      departmentId: departmentId ?? this.departmentId,
      role: role ?? this.role,
      reportingManagerId: reportingManagerId ?? this.reportingManagerId,
      designationId: designationId ?? this.designationId,
      salaryType: salaryType ?? this.salaryType,
      baseSalary: baseSalary ?? this.baseSalary,
      allowances: allowances ?? this.allowances,
      deductions: deductions ?? this.deductions,
      hra: hra ?? this.hra,
      hraDay: hraDay ?? this.hraDay,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      upiId: upiId ?? this.upiId,
      panNumber: panNumber ?? this.panNumber,
      timeboxEmployeeId: timeboxEmployeeId ?? this.timeboxEmployeeId,
      timeboxName: timeboxName ?? this.timeboxName,
    );
  }

  /// Human-readable identifier. Falls back to NZ-xxxx using ID if empty.
  String get displayCode => employeeCode.isNotEmpty
      ? employeeCode
      : (id.length >= 4 ? 'NZ-${id.substring(id.length - 4).toUpperCase()}' : 'NZ-EMP');
}

/// Selection helpers for assignment/picker dropdowns. Assignment lists should
/// only ever offer ACTIVE staff of the right role. `artistRole` is the real
/// classifier — `role`/`type` are free-text labels ("MUA", "Fleet Driver").
extension EmployeeSelection on Employee {
  /// Currently employed (case-insensitive; `status` defaults to 'active').
  bool get isActive => status.toLowerCase() == 'active';

  /// A fleet driver.
  bool get isDriver => artistRole.toLowerCase() == 'driver';

  /// A makeup artist or their assistant — the creative staff assignable to
  /// bookings and trials.
  bool get isArtist {
    final r = artistRole.toLowerCase();
    return r == 'artist' || r == 'assistant';
  }

  /// Lifecycle status helpers
  bool get isProbation => employmentStatus.toLowerCase() == 'probation';
  bool get isConfirmed => employmentStatus.toLowerCase() == 'confirmed';
  bool get isNoticePeriod => employmentStatus.toLowerCase() == 'notice_period';
  bool get isExited => employmentStatus.toLowerCase() == 'exited';
}
