import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';

// MANPOWER REQUESTS: a project asks HR for more people, and HR covers each seat with a person already on staff (their
// department's head lets them go when it is not already on the project), a new hire, or a contractor — as the server
// works it out (backend utils/manpower.js, controllers/manpowerController.js).

/// Where a request stands: submitted (nobody has touched it) · in_progress · fulfilled · declined · cancelled.
bool isOpenManpowerStatus(String status) => status == 'submitted' || status == 'in_progress';

String manpowerStatusLabel(String status) => switch (status) {
  'submitted' => 'Waiting for HR',
  'in_progress' => 'HR is on it',
  'fulfilled' => 'Covered',
  'declined' => 'Declined',
  'cancelled' => 'Withdrawn',
  _ => status,
};

/// How one seat is covered and where that stands: awaiting_release · assigned · hiring · refused.
String manpowerLineLabel(ManpowerLine l) {
  switch (l.state) {
    case 'awaiting_release':
      return 'Waiting for ${l.employeeDept.isEmpty ? 'their' : '${l.employeeDept}\'s'} head';
    case 'refused':
      return 'Not released';
    case 'hiring':
      return l.filled > 0 ? 'Hiring · ${l.filled} of ${l.seats} joined' : 'Hiring';
    default:
      return l.type == 'contract' ? 'Contractor' : 'On the project';
  }
}

class ManpowerLine {
  final String id;
  final String type; // internal | hire | contract
  final String state; // awaiting_release | assigned | hiring | refused
  final int seats;
  final int filled;
  final String employeeId;
  final String employeeName;
  final String employeeDept;
  final int percent;
  final DateTime? from;
  final DateTime? to;
  final String vendorName;
  final double cost;
  final String note;
  final String releaseNote;

  const ManpowerLine({
    required this.id,
    this.type = 'internal',
    this.state = 'assigned',
    this.seats = 1,
    this.filled = 0,
    this.employeeId = '',
    this.employeeName = '',
    this.employeeDept = '',
    this.percent = 0,
    this.from,
    this.to,
    this.vendorName = '',
    this.cost = 0,
    this.note = '',
    this.releaseNote = '',
  });

  /// The headline of the line: who, or what kind of cover.
  String get title => switch (type) {
    'internal' => employeeName.isEmpty ? 'A person on staff' : employeeName,
    'contract' => vendorName.isEmpty ? 'A contractor' : 'Contractor · $vendorName',
    _ => seats == 1 ? 'A new hire' : '$seats new hires',
  };

  factory ManpowerLine.fromJson(Map<String, dynamic> j) => ManpowerLine(
    id: (j['id'] ?? '').toString(),
    type: (j['type'] ?? 'internal').toString(),
    state: (j['state'] ?? 'assigned').toString(),
    seats: (j['seats'] as num?)?.toInt() ?? 1,
    filled: (j['filled'] as num?)?.toInt() ?? 0,
    employeeId: (j['employeeId'] ?? '').toString(),
    employeeName: (j['employeeName'] ?? '').toString(),
    employeeDept: (j['employeeDept'] ?? '').toString(),
    percent: (j['percent'] as num?)?.toInt() ?? 0,
    from: DateTime.tryParse((j['from'] ?? '').toString()),
    to: DateTime.tryParse((j['to'] ?? '').toString()),
    vendorName: (j['vendorName'] ?? '').toString(),
    cost: (j['cost'] as num?)?.toDouble() ?? 0,
    note: (j['note'] ?? '').toString(),
    releaseNote: (j['releaseNote'] ?? '').toString(),
  );
}

/// What this person may do with a request: handle it (HR), take it back (whoever asked, the project manager, the owning
/// head), and the lines they have to answer (the head of the person's department).
class ManpowerAccess {
  final bool canHandle;
  final bool canCancel;
  final List<String> releasable;
  const ManpowerAccess({this.canHandle = false, this.canCancel = false, this.releasable = const []});

  factory ManpowerAccess.fromJson(Map<String, dynamic>? j) => j == null
      ? const ManpowerAccess()
      : ManpowerAccess(
          canHandle: j['canHandle'] == true,
          canCancel: j['canCancel'] == true,
          releasable: [for (final e in (j['releasable'] as List?) ?? const []) e.toString()],
        );
}

/// Whether a seat's estimated cost fits what is left of the project's approved budget (given with a new request).
class ManpowerBudgetNote {
  final bool short;
  final double shortfall;
  final double available;
  const ManpowerBudgetNote({this.short = false, this.shortfall = 0, this.available = 0});

  factory ManpowerBudgetNote.fromJson(Map<String, dynamic> j) => ManpowerBudgetNote(
    short: j['short'] == true,
    shortfall: (j['shortfall'] as num?)?.toDouble() ?? 0,
    available: (j['available'] as num?)?.toDouble() ?? 0,
  );
}

class ManpowerRequest {
  final String id;
  final String projectId;
  final String projectName;
  final String department;
  final String requestedByName;
  final DateTime? requestedAt;
  final String roleTitle;
  final String skills;
  final int headcount;
  final DateTime? startDate;
  final DateTime? endDate;
  final int allocationPercent;
  final String urgency; // normal | urgent
  final String reason;
  final double estimatedCost;
  final String status;
  final int seatsLeft;
  final List<ManpowerLine> lines;
  final String hrOwnerName;
  final String decisionNote;
  final ManpowerAccess access;

  /// Only on the answer to a new request that named an estimated cost.
  final ManpowerBudgetNote? budget;

  const ManpowerRequest({
    required this.id,
    this.projectId = '',
    this.projectName = '',
    this.department = '',
    this.requestedByName = '',
    this.requestedAt,
    this.roleTitle = '',
    this.skills = '',
    this.headcount = 1,
    this.startDate,
    this.endDate,
    this.allocationPercent = 100,
    this.urgency = 'normal',
    this.reason = '',
    this.estimatedCost = 0,
    this.status = 'submitted',
    this.seatsLeft = 0,
    this.lines = const [],
    this.hrOwnerName = '',
    this.decisionNote = '',
    this.access = const ManpowerAccess(),
    this.budget,
  });

  bool get isOpen => isOpenManpowerStatus(status);
  bool get isUrgent => urgency == 'urgent';

  /// "2 UI designers" / "1 QA".
  String get what => '$headcount $roleTitle${headcount == 1 ? '' : 's'}';

  /// The lines this person has to answer.
  List<ManpowerLine> get toRelease => [for (final l in lines) if (access.releasable.contains(l.id) && l.state == 'awaiting_release') l];

  factory ManpowerRequest.fromJson(Map<String, dynamic> j) => ManpowerRequest(
    id: (j['id'] ?? '').toString(),
    projectId: (j['projectId'] ?? '').toString(),
    projectName: (j['projectName'] ?? '').toString(),
    department: (j['department'] ?? '').toString(),
    requestedByName: (j['requestedByName'] ?? '').toString(),
    requestedAt: DateTime.tryParse((j['requestedAt'] ?? '').toString())?.toLocal(),
    roleTitle: (j['roleTitle'] ?? '').toString(),
    skills: (j['skills'] ?? '').toString(),
    headcount: (j['headcount'] as num?)?.toInt() ?? 1,
    startDate: DateTime.tryParse((j['startDate'] ?? '').toString()),
    endDate: DateTime.tryParse((j['endDate'] ?? '').toString()),
    allocationPercent: (j['allocationPercent'] as num?)?.toInt() ?? 100,
    urgency: (j['urgency'] ?? 'normal').toString(),
    reason: (j['reason'] ?? '').toString(),
    estimatedCost: (j['estimatedCost'] as num?)?.toDouble() ?? 0,
    status: (j['status'] ?? 'submitted').toString(),
    seatsLeft: (j['seatsLeft'] as num?)?.toInt() ?? 0,
    lines: [
      for (final e in (j['lines'] as List?) ?? const [])
        if (e is Map) ManpowerLine.fromJson(e.cast<String, dynamic>()),
    ],
    hrOwnerName: (j['hrOwnerName'] ?? '').toString(),
    decisionNote: (j['decisionNote'] ?? '').toString(),
    access: ManpowerAccess.fromJson((j['access'] as Map?)?.cast<String, dynamic>()),
    budget: j['budget'] is Map ? ManpowerBudgetNote.fromJson((j['budget'] as Map).cast<String, dynamic>()) : null,
  );
}

/// A person on staff, with how much of their time is spoken for in the window HR is looking at.
class AvailablePerson {
  final String id;
  final String name;
  final String department;
  final String role;
  final int load;
  final bool onLeave;
  final int openTasks;

  /// free · tight · busy — judged with the time being asked for added to what they already have.
  final String level;

  const AvailablePerson({required this.id, required this.name, this.department = '', this.role = '', this.load = 0, this.onLeave = false, this.openTasks = 0, this.level = 'free'});

  bool get isBusy => level == 'busy';

  /// "70% booked" / "On leave" / "Free".
  String get loadLabel => onLeave ? 'On leave' : (load <= 0 ? 'Nothing booked' : '$load% booked');

  factory AvailablePerson.fromJson(Map<String, dynamic> j) => AvailablePerson(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    department: (j['department'] ?? '').toString(),
    role: (j['role'] ?? '').toString(),
    load: (j['load'] as num?)?.toInt() ?? 0,
    onLeave: j['onLeave'] == true,
    openTasks: (j['openTasks'] as num?)?.toInt() ?? 0,
    level: (j['level'] ?? 'free').toString(),
  );
}

/// What HR is looking at when choosing people: the days, how much of their time, and what to search for.
class AvailabilityQuery {
  final DateTime? from;
  final DateTime? to;
  final int percent;
  final String search;
  const AvailabilityQuery({this.from, this.to, this.percent = 100, this.search = ''});

  @override
  bool operator ==(Object other) => other is AvailabilityQuery && other.from == from && other.to == to && other.percent == percent && other.search == search;

  @override
  int get hashCode => Object.hash(from, to, percent, search);
}

/// One person on a project's team: how much of their time, and when.
class TeamMember {
  final String id;
  final String employeeId;
  final String employeeName;
  final String role;
  final int percent;
  final DateTime? from;
  final DateTime? to;

  /// upcoming · active · ended
  final String state;
  const TeamMember({required this.id, this.employeeId = '', this.employeeName = '', this.role = '', this.percent = 100, this.from, this.to, this.state = 'active'});

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
    id: (j['id'] ?? '').toString(),
    employeeId: (j['employeeId'] ?? '').toString(),
    employeeName: (j['employeeName'] ?? '').toString(),
    role: (j['role'] ?? '').toString(),
    percent: (j['percent'] as num?)?.toInt() ?? 100,
    from: DateTime.tryParse((j['from'] ?? '').toString()),
    to: DateTime.tryParse((j['to'] ?? '').toString()),
    state: (j['state'] ?? 'active').toString(),
  );
}

/// HR's choice for one batch of seats; sent as one line of the "handle" call.
class ManpowerChoice {
  final String type; // internal | hire | contract
  final String employeeId;
  final int? percent;
  final int seats;
  final double? cost;
  final String vendorName;
  final String note;
  const ManpowerChoice.person(this.employeeId, {this.percent, this.note = ''})
    : type = 'internal',
      seats = 1,
      cost = null,
      vendorName = '';
  const ManpowerChoice.hire({this.seats = 1, this.cost, this.note = ''})
    : type = 'hire',
      employeeId = '',
      percent = null,
      vendorName = '';
  const ManpowerChoice.contractor({required this.vendorName, this.seats = 1, this.cost, this.note = ''})
    : type = 'contract',
      employeeId = '',
      percent = null;

  Map<String, dynamic> toJson() => {
    'type': type,
    if (type == 'internal') 'employeeId': employeeId,
    if (type == 'internal' && percent != null) 'percent': percent,
    if (type != 'internal') 'seats': seats,
    if (type != 'internal' && cost != null) 'cost': cost,
    if (type == 'contract') 'vendorName': vendorName,
    if (note.trim().isNotEmpty) 'note': note.trim(),
  };
}

/// The server asked a question instead of doing it: the person is already busy then ("assign anyway?"), or the seat's cost
/// does not fit the project's approved budget.
class ManpowerRefusal {
  final String code; // MANPOWER_CONFLICT | NEEDS_BUDGET
  final String message;
  final String employeeName;
  final int load;
  final bool onLeave;
  final double shortfall;
  final double available;
  const ManpowerRefusal({required this.code, required this.message, this.employeeName = '', this.load = 0, this.onLeave = false, this.shortfall = 0, this.available = 0});

  /// HR may go ahead anyway.
  bool get isConflict => code == 'MANPOWER_CONFLICT';
  bool get needsBudget => code == 'NEEDS_BUDGET';

  /// The refusal inside [error], or null when it is some other failure.
  static ManpowerRefusal? of(Object? error) {
    final cause = error is AppException ? error.cause : error;
    if (cause is! DioException || cause.response?.statusCode != 409) return null;
    final data = cause.response?.data;
    if (data is! Map) return null;
    final code = '${data['code'] ?? ''}';
    if (code != 'MANPOWER_CONFLICT' && code != 'NEEDS_BUDGET') return null;
    double n(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return ManpowerRefusal(
      code: code,
      message: '${data['message'] ?? ''}',
      employeeName: '${data['employeeName'] ?? ''}',
      load: n(data['load']).toInt(),
      onLeave: data['onLeave'] == true,
      shortfall: n(data['shortfall']),
      available: n(data['available']),
    );
  }
}
