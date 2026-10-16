// EmployeeDocument model — mirrors backend/models/EmployeeDocument.js.

const kDocumentCategories = <String>[
  'id_proof',
  'contract',
  'certificate',
  'offer_letter',
  'experience_letter',
  'resume',
  'payslip',
  'other',
];

String documentCategoryLabel(String c) {
  switch (c) {
    case 'id_proof':
      return 'ID Proof';
    case 'contract':
      return 'Contract';
    case 'certificate':
      return 'Certificate';
    case 'offer_letter':
      return 'Offer Letter';
    case 'experience_letter':
      return 'Experience Letter';
    case 'resume':
      return 'Resume';
    case 'payslip':
      return 'Payslip';
    default:
      return 'Other';
  }
}

DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

class EmployeeDocument {
  final String id;
  final String employeeId;
  final String employeeName;
  final String category;
  final String title;
  final String description;
  final String fileType;
  final String fileName;
  final DateTime? expiresOn;
  final String uploadedByName;
  final DateTime? createdAt;

  const EmployeeDocument({
    required this.id,
    required this.employeeId,
    this.employeeName = '',
    this.category = 'other',
    this.title = '',
    this.description = '',
    this.fileType = 'other',
    this.fileName = '',
    this.expiresOn,
    this.uploadedByName = '',
    this.createdAt,
  });

  factory EmployeeDocument.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return EmployeeDocument(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? '',
      category: j['category'] as String? ?? 'other',
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      fileType: j['fileType'] as String? ?? 'other',
      fileName: j['fileName'] as String? ?? '',
      expiresOn: _date(j['expiresOn']),
      uploadedByName: j['uploadedByName'] as String? ?? '',
      createdAt: _date(j['createdAt']),
    );
  }
}
