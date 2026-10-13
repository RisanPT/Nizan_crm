// Recruitment models — mirror backend JobPost / Candidate / Offer.

const kCandidateStages = <String>['applied', 'screening', 'interview', 'offer', 'hired', 'rejected'];
const kCandidateSources = <String>['website', 'referral', 'job_portal', 'agency', 'walk-in', 'social', 'campus', 'other'];
const kJobPostStatuses = <String>['open', 'on_hold', 'closed'];
const kOfferStatuses = <String>['draft', 'sent', 'accepted', 'declined', 'withdrawn'];

String titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());
String _idOf(dynamic v) => v is Map ? ((v['_id'] as String?) ?? '') : ((v as String?) ?? '');
String _nameOf(dynamic v) => v is Map ? ((v['name'] as String?) ?? '') : '';

class JobPost {
  final String id;
  final String title;
  final String department;
  final String designationId;
  final String designationName;
  final String location;
  final String type;
  final int openings;
  final String description;
  final String status;
  final int candidateCount;

  const JobPost({
    required this.id,
    this.title = '',
    this.department = '',
    this.designationId = '',
    this.designationName = '',
    this.location = '',
    this.type = 'full-time',
    this.openings = 1,
    this.description = '',
    this.status = 'open',
    this.candidateCount = 0,
  });

  factory JobPost.fromJson(Map<String, dynamic> j) => JobPost(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        department: j['department'] as String? ?? '',
        designationId: _idOf(j['designationId']),
        designationName: _nameOf(j['designationId']),
        location: j['location'] as String? ?? '',
        type: j['type'] as String? ?? 'full-time',
        openings: j['openings'] == null ? 1 : _i(j['openings']),
        description: j['description'] as String? ?? '',
        status: j['status'] as String? ?? 'open',
        candidateCount: _i(j['candidateCount']),
      );
}

class Candidate {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String jobPostId;
  final String jobTitle;
  final String source;
  final String referrer;
  final String stage;
  final int rating;
  final String resumeUrl;
  final String notes;

  const Candidate({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.jobPostId = '',
    this.jobTitle = '',
    this.source = 'website',
    this.referrer = '',
    this.stage = 'applied',
    this.rating = 0,
    this.resumeUrl = '',
    this.notes = '',
  });

  factory Candidate.fromJson(Map<String, dynamic> j) => Candidate(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        jobPostId: _idOf(j['jobPostId']),
        jobTitle: j['jobTitle'] as String? ?? '',
        source: j['source'] as String? ?? 'website',
        referrer: j['referrer'] as String? ?? '',
        stage: j['stage'] as String? ?? 'applied',
        rating: _i(j['rating']),
        resumeUrl: j['resumeUrl'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
      );
}

class Offer {
  final String id;
  final String candidateId;
  final String candidateName;
  final String designation;
  final String department;
  final double salary;
  final DateTime? joiningDate;
  final String status;
  final String employeeId;

  const Offer({
    required this.id,
    this.candidateId = '',
    this.candidateName = '',
    this.designation = '',
    this.department = '',
    this.salary = 0,
    this.joiningDate,
    this.status = 'draft',
    this.employeeId = '',
  });

  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        candidateId: _idOf(j['candidateId']),
        candidateName: j['candidateName'] as String? ?? '',
        designation: j['designation'] as String? ?? '',
        department: j['department'] as String? ?? '',
        salary: _d(j['salary']),
        joiningDate: _date(j['joiningDate']),
        status: j['status'] as String? ?? 'draft',
        employeeId: _idOf(j['employeeId']),
      );
}

class RoleSkill {
  final String name;
  final double score;

  const RoleSkill({required this.name, this.score = 4.5});

  factory RoleSkill.fromJson(Map<String, dynamic> j) => RoleSkill(
        name: j['name'] as String? ?? '',
        score: _d(j['score']),
      );
}

class JobRole {
  final String id;
  final String roleCode;
  final String designation;
  final String shortTitle;
  final String dept;
  final String band;
  final int tier;
  final String? parentId;
  final String reportsTo;
  final String team;
  final int headcount;
  final String purpose;
  final List<String> responsibilities;
  final String deliverables;
  final String exp;
  final String qual;
  final List<RoleSkill> skills;
  final List<String> competencies;
  final bool active;

  const JobRole({
    required this.id,
    this.roleCode = '',
    this.designation = '',
    this.shortTitle = '',
    this.dept = '',
    this.band = 'L3',
    this.tier = 5,
    this.parentId,
    this.reportsTo = '',
    this.team = '',
    this.headcount = 1,
    this.purpose = '',
    this.responsibilities = const [],
    this.deliverables = '',
    this.exp = '2-4 yrs',
    this.qual = '',
    this.skills = const [],
    this.competencies = const [],
    this.active = true,
  });

  factory JobRole.fromJson(Map<String, dynamic> j) {
    final rawSkills = j['skills'] as List? ?? [];
    final rawResp = j['responsibilities'] as List? ?? [];
    final rawComp = j['competencies'] as List? ?? [];

    return JobRole(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      roleCode: j['roleCode'] as String? ?? '',
      designation: j['designation'] as String? ?? '',
      shortTitle: j['shortTitle'] as String? ?? (j['designation'] as String? ?? ''),
      dept: j['dept'] as String? ?? '',
      band: j['band'] as String? ?? 'L3',
      tier: _i(j['tier']) == 0 ? 5 : _i(j['tier']),
      parentId: j['parentId'] as String?,
      reportsTo: j['reportsTo'] as String? ?? '',
      team: j['team'] as String? ?? '',
      headcount: _i(j['headcount']) == 0 ? 1 : _i(j['headcount']),
      purpose: j['purpose'] as String? ?? '',
      responsibilities: rawResp.map((e) => e.toString()).toList(),
      deliverables: j['deliverables'] as String? ?? '',
      exp: j['exp'] as String? ?? '2-4 yrs',
      qual: j['qual'] as String? ?? '',
      skills: rawSkills.map((e) => RoleSkill.fromJson(e as Map<String, dynamic>)).toList(),
      competencies: rawComp.map((e) => e.toString()).toList(),
      active: j['active'] as bool? ?? true,
    );
  }
}

class HiringPlan {
  final String id;
  final String? roleId;
  final String designation;
  final String department;
  final int openings;
  final String employmentType;
  final String reportingLine;
  final String businessJustification;
  final String jobDescription;
  final String requiredSkills;
  final String experienceBand;
  final String competencies;
  final String status; // 'draft', 'raised', 'approved', 'rejected'
  final DateTime? raisedAt;
  final DateTime? approvedAt;
  final String rejectionReason;

  const HiringPlan({
    required this.id,
    this.roleId,
    this.designation = '',
    this.department = '',
    this.openings = 1,
    this.employmentType = 'Full-time',
    this.reportingLine = '',
    this.businessJustification = '',
    this.jobDescription = '',
    this.requiredSkills = '',
    this.experienceBand = '',
    this.competencies = '',
    this.status = 'draft',
    this.raisedAt,
    this.approvedAt,
    this.rejectionReason = '',
  });

  factory HiringPlan.fromJson(Map<String, dynamic> j) => HiringPlan(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        roleId: _idOf(j['roleId']),
        designation: j['designation'] as String? ?? '',
        department: j['department'] as String? ?? '',
        openings: _i(j['openings']) == 0 ? 1 : _i(j['openings']),
        employmentType: j['employmentType'] as String? ?? 'Full-time',
        reportingLine: j['reportingLine'] as String? ?? '',
        businessJustification: j['businessJustification'] as String? ?? '',
        jobDescription: j['jobDescription'] as String? ?? '',
        requiredSkills: j['requiredSkills'] as String? ?? '',
        experienceBand: j['experienceBand'] as String? ?? '',
        competencies: j['competencies'] as String? ?? '',
        status: j['status'] as String? ?? 'draft',
        raisedAt: _date(j['raisedAt']),
        approvedAt: _date(j['approvedAt']),
        rejectionReason: j['rejectionReason'] as String? ?? '',
      );
}
