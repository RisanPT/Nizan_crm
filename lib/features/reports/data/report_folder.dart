/// A folder that categorises company-report documents within a department.
class ReportFolder {
  final String id;
  final String name;
  final String department;
  final String createdById;

  const ReportFolder({
    required this.id,
    required this.name,
    required this.department,
    this.createdById = '',
  });

  factory ReportFolder.fromJson(Map<String, dynamic> j) {
    final by = j['createdBy'];
    return ReportFolder(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      department: (j['department'] ?? '').toString(),
      createdById: by is Map ? (by['_id'] ?? '').toString() : (by ?? '').toString(),
    );
  }
}
