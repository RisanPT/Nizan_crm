// Grievance model — mirrors backend/models/Grievance.js.

const kGrievanceCategories = <String>['workplace', 'harassment', 'payroll', 'facilities', 'management', 'other'];
const kGrievanceStatuses = <String>['open', 'in_review', 'resolved', 'closed'];

String grievanceLabel(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

class Grievance {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String category;
  final String subject;
  final String description;
  final bool confidential;
  final String status;
  final String assignedToName;
  final String resolutionNote;
  final DateTime? createdAt;

  const Grievance({
    required this.id,
    this.employeeId = '',
    this.employeeName = '',
    this.department = '',
    this.category = 'other',
    this.subject = '',
    this.description = '',
    this.confidential = false,
    this.status = 'open',
    this.assignedToName = '',
    this.resolutionNote = '',
    this.createdAt,
  });

  factory Grievance.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    final assignee = j['assignedTo'];
    final assigneeMap = assignee is Map<String, dynamic> ? assignee : null;
    return Grievance(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      department: empMap?['department'] as String? ?? j['department'] as String? ?? '',
      category: j['category'] as String? ?? 'other',
      subject: j['subject'] as String? ?? '',
      description: j['description'] as String? ?? '',
      confidential: j['confidential'] as bool? ?? false,
      status: j['status'] as String? ?? 'open',
      assignedToName: assigneeMap?['name'] as String? ?? '',
      resolutionNote: j['resolutionNote'] as String? ?? '',
      createdAt: _date(j['createdAt']),
    );
  }
}

const grievanceCategories = kGrievanceCategories;
const grievanceStatuses = kGrievanceStatuses;
