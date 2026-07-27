class Vendor {
  final String id;
  final String name;
  final String gstNumber;
  final String phone;
  final String email;
  final String address;
  final String state;
  final String stateCode;
  final String bankName;
  final String bankAccount;
  final String bankIfsc;
  final String notes;

  const Vendor({
    required this.id,
    required this.name,
    this.gstNumber = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.state = '',
    this.stateCode = '',
    this.bankName = '',
    this.bankAccount = '',
    this.bankIfsc = '',
    this.notes = '',
  });

  factory Vendor.fromJson(Map<String, dynamic> json) => Vendor(
        id: json['_id'] as String? ?? json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        gstNumber: json['gstNumber'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        address: json['address'] as String? ?? '',
        state: json['state'] as String? ?? '',
        stateCode: json['stateCode'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        bankAccount: json['bankAccount'] as String? ?? '',
        bankIfsc: json['bankIfsc'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'gstNumber': gstNumber,
        'phone': phone,
        'email': email,
        'address': address,
        'state': state,
        'stateCode': stateCode,
        'bankName': bankName,
        'bankAccount': bankAccount,
        'bankIfsc': bankIfsc,
        'notes': notes,
      };

  String get subtitle {
    final parts = <String>[];
    if (gstNumber.isNotEmpty) parts.add('GST $gstNumber');
    if (phone.isNotEmpty) parts.add(phone);
    return parts.join(' · ');
  }

  // Identity by id so dropdown selections match across provider re-fetches.
  @override
  bool operator ==(Object other) =>
      other is Vendor && other.id == id && id.isNotEmpty;

  @override
  int get hashCode => id.hashCode;
}
