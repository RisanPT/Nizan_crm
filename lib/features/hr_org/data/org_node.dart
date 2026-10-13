// OrgNode — one row of GET /api/employees/org-tree. The client assembles the
// reporting tree (manager → reports) from reportingManagerId.

class OrgNode {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String status;
  final String department;
  final String? departmentId;
  final String designation;
  final String? designationId;
  final int? designationLevel;
  final String? reportingManagerId;
  final String profileImage;

  const OrgNode({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.status = 'active',
    this.department = '',
    this.departmentId,
    this.designation = '',
    this.designationId,
    this.designationLevel,
    this.reportingManagerId,
    this.profileImage = '',
  });

  factory OrgNode.fromJson(Map<String, dynamic> j) => OrgNode(
        id: j['id'] as String? ?? j['_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        department: j['department'] as String? ?? '',
        departmentId: j['departmentId'] as String?,
        designation: j['designation'] as String? ?? '',
        designationId: j['designationId'] as String?,
        designationLevel: (j['designationLevel'] as num?)?.toInt(),
        reportingManagerId: j['reportingManagerId'] as String?,
        profileImage: j['profileImage'] as String? ?? '',
      );
}
