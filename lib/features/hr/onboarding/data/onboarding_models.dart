// Onboarding models — mirror backend/models/Onboarding.js.

DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

class OnboardingTask {
  final String title;
  final bool done;
  final String owner;
  final DateTime? dueDate;
  final String note;

  const OnboardingTask({
    required this.title,
    this.done = false,
    this.owner = '',
    this.dueDate,
    this.note = '',
  });

  factory OnboardingTask.fromJson(Map<String, dynamic> j) => OnboardingTask(
        title: j['title'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        owner: j['owner'] as String? ?? '',
        dueDate: _date(j['dueDate']),
        note: j['note'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'done': done,
        'owner': owner,
        'dueDate': dueDate?.toIso8601String(),
        'note': note,
      };

  OnboardingTask copyWith({bool? done, String? title, String? owner, DateTime? dueDate, String? note}) =>
      OnboardingTask(
        title: title ?? this.title,
        done: done ?? this.done,
        owner: owner ?? this.owner,
        dueDate: dueDate ?? this.dueDate,
        note: note ?? this.note,
      );
}

class OnboardingDocument {
  final String name;
  final String owner;
  final bool required;
  final String status; // 'Received', 'Pending', 'Not required'

  const OnboardingDocument({
    required this.name,
    this.owner = '',
    this.required = true,
    this.status = 'Pending',
  });

  factory OnboardingDocument.fromJson(Map<String, dynamic> j) => OnboardingDocument(
        name: j['name'] as String? ?? '',
        owner: j['owner'] as String? ?? '',
        required: j['required'] as bool? ?? true,
        status: j['status'] as String? ?? 'Pending',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'owner': owner,
        'required': required,
        'status': status,
      };

  OnboardingDocument copyWith({
    String? name,
    String? owner,
    bool? required,
    String? status,
  }) =>
      OnboardingDocument(
        name: name ?? this.name,
        owner: owner ?? this.owner,
        required: required ?? this.required,
        status: status ?? this.status,
      );
}

class Onboarding {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String role;
  final DateTime? joiningDate;
  final String? candidateId;
  final String? offerId;
  final String status; // in_progress | completed
  final DateTime? startedOn;
  final DateTime? completedOn;
  final List<OnboardingTask> tasks;
  final List<OnboardingDocument> documents;

  const Onboarding({
    required this.id,
    this.employeeId = '',
    this.employeeName = '',
    this.department = '',
    this.role = '',
    this.joiningDate,
    this.candidateId,
    this.offerId,
    this.status = 'in_progress',
    this.startedOn,
    this.completedOn,
    this.tasks = const [],
    this.documents = const [],
  });

  int get doneCount => tasks.where((t) => t.done).length;
  double get progressPercentage => tasks.isEmpty ? 0.0 : doneCount / tasks.length;
  int get pendingDocsCount => documents.where((d) => d.status.toLowerCase() == 'pending').length;

  factory Onboarding.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return Onboarding(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      department: empMap?['department'] as String? ?? j['department'] as String? ?? '',
      role: empMap?['role'] as String? ?? j['role'] as String? ?? '',
      joiningDate: _date(j['joiningDate']),
      candidateId: j['candidateId'] as String?,
      offerId: j['offerId'] as String?,
      status: j['status'] as String? ?? 'in_progress',
      startedOn: _date(j['startedOn']),
      completedOn: _date(j['completedOn']),
      tasks: ((j['tasks'] as List?) ?? const [])
          .map((e) => OnboardingTask.fromJson(e as Map<String, dynamic>))
          .toList(),
      documents: ((j['documents'] as List?) ?? const [])
          .map((e) => OnboardingDocument.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
