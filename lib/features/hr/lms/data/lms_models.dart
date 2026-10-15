// LMS & Orientation models — mirror Course.js, Enrollment.js, OrientationPlan.js, OrientationAssignment.js.

const kCourseCategories = <String>['orientation', 'skills', 'compliance', 'leadership', 'product', 'management', 'other'];

String courseCategoryLabel(String c) => c.isEmpty ? 'Other' : c[0].toUpperCase() + c.substring(1);

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

class Course {
  final String id;
  final String title;
  final String description;
  final String category;
  final String department;
  final String targetRole;
  final String url;
  final double durationHours;
  final bool active;

  const Course({
    required this.id,
    this.title = '',
    this.description = '',
    this.category = 'skills',
    this.department = 'Technology & Systems (IT)',
    this.targetRole = '',
    this.url = '',
    this.durationHours = 0,
    this.active = true,
  });

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        category: j['category'] as String? ?? 'skills',
        department: j['department'] as String? ?? 'Technology & Systems (IT)',
        targetRole: j['targetRole'] as String? ?? '',
        url: j['url'] as String? ?? '',
        durationHours: _d(j['durationHours']),
        active: j['active'] as bool? ?? true,
      );
}

class Enrollment {
  final String id;
  final String employeeId;
  final String employeeName;
  final String courseId;
  final String courseTitle;
  final String status; // enrolled | in_progress | completed
  final int progress;
  final DateTime? completedOn;

  const Enrollment({
    required this.id,
    this.employeeId = '',
    this.employeeName = '',
    this.courseId = '',
    this.courseTitle = '',
    this.status = 'enrolled',
    this.progress = 0,
    this.completedOn,
  });

  factory Enrollment.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return Enrollment(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      courseId: j['courseId'] is Map ? (j['courseId']['_id'] as String? ?? '') : (j['courseId'] as String? ?? ''),
      courseTitle: j['courseTitle'] as String? ?? '',
      status: j['status'] as String? ?? 'enrolled',
      progress: _i(j['progress']),
      completedOn: _date(j['completedOn']),
    );
  }
}

class OrientationDay {
  final int dayNumber;
  final String title;
  final List<String> topics;
  final bool mandatorySignOff;
  final String notes;

  const OrientationDay({
    required this.dayNumber,
    required this.title,
    this.topics = const [],
    this.mandatorySignOff = true,
    this.notes = '',
  });

  factory OrientationDay.fromJson(Map<String, dynamic> j) => OrientationDay(
        dayNumber: _i(j['dayNumber']),
        title: j['title'] as String? ?? '',
        topics: (j['topics'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        mandatorySignOff: j['mandatorySignOff'] as bool? ?? true,
        notes: j['notes'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'title': title,
        'topics': topics,
        'mandatorySignOff': mandatorySignOff,
        'notes': notes,
      };
}

class OrientationPlan {
  final String id;
  final String roleTitle;
  final String department;
  final String trainerName;
  final String overview;
  final String documentUrl;
  final String documentContent;
  final String status;
  final List<OrientationDay> days;

  const OrientationPlan({
    required this.id,
    required this.roleTitle,
    required this.department,
    this.trainerName = 'Department Lead',
    this.overview = '',
    this.documentUrl = '',
    this.documentContent = '',
    this.status = 'Active',
    this.days = const [],
  });

  factory OrientationPlan.fromJson(Map<String, dynamic> j) => OrientationPlan(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        roleTitle: j['roleTitle'] as String? ?? '',
        department: j['department'] as String? ?? '',
        trainerName: j['trainerName'] as String? ?? 'Department Lead',
        overview: j['overview'] as String? ?? '',
        documentUrl: j['documentUrl'] as String? ?? '',
        documentContent: j['documentContent'] as String? ?? '',
        status: j['status'] as String? ?? 'Active',
        days: (j['days'] as List?)?.map((e) => OrientationDay.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'roleTitle': roleTitle,
        'department': department,
        'trainerName': trainerName,
        'overview': overview,
        'documentUrl': documentUrl,
        'documentContent': documentContent,
        'status': status,
        'days': days.map((d) => d.toJson()).toList(),
      };
}

class OrientationDayProgress {
  final int dayNumber;
  final String title;
  final List<String> topics;
  final bool signedOff;
  final String signedOffBy;
  final DateTime? signedOffAt;
  final String status; // Signed | In progress | Upcoming | Pending
  final String notes;

  const OrientationDayProgress({
    required this.dayNumber,
    required this.title,
    this.topics = const [],
    this.signedOff = false,
    this.signedOffBy = '',
    this.signedOffAt,
    this.status = 'Upcoming',
    this.notes = '',
  });

  factory OrientationDayProgress.fromJson(Map<String, dynamic> j) => OrientationDayProgress(
        dayNumber: _i(j['dayNumber']),
        title: j['title'] as String? ?? '',
        topics: (j['topics'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        signedOff: j['signedOff'] as bool? ?? false,
        signedOffBy: j['signedOffBy'] as String? ?? '',
        signedOffAt: _date(j['signedOffAt']),
        status: j['status'] as String? ?? 'Upcoming',
        notes: j['notes'] as String? ?? '',
      );
}

class OrientationAssignment {
  final String id;
  final String employeeId;
  final String employeeName;
  final String roleTitle;
  final String department;
  final String trainerName;
  final DateTime? startDate;
  final int currentDay;
  final int totalDays;
  final String status; // On track | Due today | Overdue | Completed
  final List<OrientationDayProgress> days;

  const OrientationAssignment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.roleTitle,
    this.department = '',
    this.trainerName = 'Department Lead',
    this.startDate,
    this.currentDay = 1,
    this.totalDays = 7,
    this.status = 'On track',
    this.days = const [],
  });

  int get signedOffCount => days.where((d) => d.signedOff).length;

  factory OrientationAssignment.fromJson(Map<String, dynamic> j) {
    return OrientationAssignment(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: j['employeeId'] is Map ? (j['employeeId']['_id'] as String? ?? '') : (j['employeeId'] as String? ?? ''),
      employeeName: j['employeeName'] as String? ?? '',
      roleTitle: j['roleTitle'] as String? ?? '',
      department: j['department'] as String? ?? '',
      trainerName: j['trainerName'] as String? ?? 'Department Lead',
      startDate: _date(j['startDate']),
      currentDay: _i(j['currentDay']),
      totalDays: _i(j['totalDays']),
      status: j['status'] as String? ?? 'On track',
      days: (j['days'] as List?)?.map((e) => OrientationDayProgress.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
    );
  }
}
