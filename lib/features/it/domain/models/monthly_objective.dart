// Monthly objectives per department (GET /api/monthly-objectives): each department's objectives for a month, each with key results.
// Mirrors backend utils/monthlyObjectives.js — progress is worked out by the server and sent ready.

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List ? v.map(_m).toList() : const <Map<String, dynamic>>[];

typedef MonthKey = ({int year, int month});

const kMonthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
String monthTitle(MonthKey m) => '${kMonthNames[m.month - 1]} ${m.year}';
MonthKey nextMonthOf(MonthKey m) => m.month == 12 ? (year: m.year + 1, month: 1) : (year: m.year, month: m.month + 1);
MonthKey prevMonthOf(MonthKey m) => m.month == 1 ? (year: m.year - 1, month: 12) : (year: m.year, month: m.month - 1);

/// How a month's objective ended. Achieved / partly / missed are the scored results; the others are not scored and stay out of the
/// month's average: [continued] (a several-month objective with months to go), [cancelled] (dropped), [deferred] (postponed).
enum ObjectiveResult {
  achieved,
  partly,
  missed,
  continued,
  cancelled,
  deferred;

  /// The three a month-end is judged by.
  static const scored = [achieved, partly, missed];

  String get slug => name;
  String get label => switch (this) {
        ObjectiveResult.achieved => 'Achieved',
        ObjectiveResult.partly => 'Partly',
        ObjectiveResult.missed => 'Missed',
        ObjectiveResult.continued => 'Continues',
        ObjectiveResult.cancelled => 'Cancelled',
        ObjectiveResult.deferred => 'Postponed',
      };

  /// How a count of them reads: "2 continuing".
  String get tally => switch (this) {
        ObjectiveResult.continued => 'continuing',
        ObjectiveResult.deferred => 'postponed',
        _ => name,
      };

  static ObjectiveResult? parse(dynamic v) {
    final s = v?.toString();
    for (final r in values) {
      if (r.name == s) return r;
    }
    return null;
  }
}

/// What a key result measures: a count to reach, a share of 100, or simply done / not done.
enum KeyResultKind {
  number,
  percent,
  yesno;

  String get slug => name;
  String get label => switch (this) {
        KeyResultKind.number => 'Number',
        KeyResultKind.percent => 'Percent',
        KeyResultKind.yesno => 'Yes / No',
      };

  static KeyResultKind parse(dynamic v) {
    final s = v?.toString();
    for (final k in values) {
      if (k.name == s) return k;
    }
    return KeyResultKind.number; // an older key result says nothing: it was a number
  }
}

/// Where a several-month objective is in its run: "month 2 of 3".
class ObjectiveSpan {
  const ObjectiveSpan({required this.number, required this.total, this.isFinal = false, this.overran = false});
  final int number;
  final int total;
  final bool isFinal;
  final bool overran;

  factory ObjectiveSpan.fromJson(Map<String, dynamic> j) =>
      ObjectiveSpan(number: _i(j['number']), total: _i(j['total']), isFinal: j['final'] == true, overran: j['overran'] == true);
}

/// A change made to the plan after its month had started: what changed and why.
class ObjectiveChange {
  const ObjectiveChange({this.at, this.byName = '', this.reason = '', this.summary = const []});
  final DateTime? at;
  final String byName;
  final String reason;
  final List<String> summary;

  factory ObjectiveChange.fromJson(Map<String, dynamic> j) => ObjectiveChange(
        at: DateTime.tryParse(_s(j['at']))?.toLocal(),
        byName: _s(j['byName']),
        reason: _s(j['reason']),
        summary: ((j['summary'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

class KeyResultCheckIn {
  const KeyResultCheckIn({required this.value, required this.completed, this.at, this.byName = ''});
  final double value;
  final bool completed;
  final DateTime? at;
  final String byName;

  factory KeyResultCheckIn.fromJson(Map<String, dynamic> j) => KeyResultCheckIn(
        value: _d(j['value']),
        completed: j['completed'] == true,
        at: DateTime.tryParse(_s(j['at']))?.toLocal(),
        byName: _s(j['byName']),
      );
}

class MonthlyKeyResult {
  const MonthlyKeyResult({
    required this.id,
    required this.title,
    required this.targetValue,
    this.currentValue = 0,
    this.unit = '',
    this.metric = '',
    this.kind = KeyResultKind.number,
    this.completed = false,
    this.completedAt,
    this.completedByName = '',
    this.checkIns = const [],
  });

  final String id;
  final String title;
  final KeyResultKind kind;
  final String metric;
  final String unit;
  final double targetValue;
  final double currentValue;
  final bool completed;

  /// When it was finished and by whom (absent for one that reached its target on its own).
  final DateTime? completedAt;
  final String completedByName;
  final List<KeyResultCheckIn> checkIns;

  /// 0–100: done is 100, else current ÷ target (as the server counts it).
  double get attainment {
    if (completed) return 100;
    if (targetValue <= 0) return 0;
    return (currentValue / targetValue * 100).clamp(0, 100).toDouble();
  }

  factory MonthlyKeyResult.fromJson(Map<String, dynamic> j) => MonthlyKeyResult(
        id: _s(j['id']),
        title: _s(j['title']),
        kind: KeyResultKind.parse(j['kind']),
        metric: _s(j['metric']),
        unit: _s(j['unit']),
        targetValue: _d(j['targetValue']),
        currentValue: _d(j['currentValue']),
        completed: j['completed'] == true,
        completedAt: DateTime.tryParse(_s(j['completedAt']))?.toLocal(),
        completedByName: _s(j['completedByName']),
        checkIns: _l(j['checkIns']).map(KeyResultCheckIn.fromJson).toList(),
      );
}

/// What this person may do to one objective (the server decides; the app only shows or hides the buttons).
class ObjectiveAccess {
  const ObjectiveAccess({this.canManage = false, this.canCheckIn = false});
  final bool canManage;
  final bool canCheckIn;

  factory ObjectiveAccess.fromJson(Map<String, dynamic> j) => ObjectiveAccess(canManage: j['canManage'] == true, canCheckIn: j['canCheckIn'] == true);
}

class MonthlyObjective {
  const MonthlyObjective({
    required this.id,
    required this.departmentId,
    required this.departmentName,
    required this.year,
    required this.month,
    required this.objective,
    this.description = '',
    this.priority = 'medium',
    this.ownerId,
    this.ownerName = '',
    this.keyResults = const [],
    this.progress = 0,
    this.span,
    this.suggested,
    this.suggestionKnown = false,
    this.result,
    this.resultNote = '',
    this.closedAt,
    this.progressAtClose,
    this.overridden = false,
    this.planLocked = false,
    this.readyToClose = false,
    this.assignedToMe = false,
    this.changes = const [],
    this.carriedFrom = false,
    this.carriedTo = false,
    this.updatedAt = '',
    this.access = const ObjectiveAccess(),
  });

  final String id;
  final String departmentId;
  final String departmentName;
  final int year;
  final int month;
  final String objective;
  final String description;
  final String priority;
  final String? ownerId;
  final String ownerName;
  final List<MonthlyKeyResult> keyResults;
  final int progress;

  /// Set for an objective that runs several months.
  final ObjectiveSpan? span;
  final ObjectiveResult? suggested;
  final bool suggestionKnown; // the server said (even if it said "none")
  final ObjectiveResult? result;
  final String resultNote;
  final DateTime? closedAt;

  /// How far it had got when it was closed, and whether it ended differently from what that pointed to (then it has a note).
  final int? progressAtClose;
  final bool overridden;

  /// True once its month has started (and it is more than a day old): changing the title or key results then needs a reason.
  final bool planLocked;

  /// Every key result is done and it is still open — the head can close it as achieved with one tap (the server decides: not for a
  /// several-month objective with months to go).
  final bool readyToClose;

  /// Given to the person looking at it (they are its owner).
  final bool assignedToMe;
  final List<ObjectiveChange> changes;
  final bool carriedFrom;
  final bool carriedTo;

  /// Sent back as `expectedUpdatedAt`, so an edit made on a stale copy is refused instead of overwriting someone's change.
  final String updatedAt;
  final ObjectiveAccess access;

  bool get isClosed => result != null;

  /// Is anything left to do? Not if achieved or cancelled; with key results, only if one is unfinished.
  bool get hasWorkLeft => result != ObjectiveResult.achieved && result != ObjectiveResult.cancelled && (keyResults.isEmpty || keyResults.any((k) => k.attainment < 100));

  /// What the close-out starts from — what the progress points to (the server's word): all key results done is achieved, half way
  /// partly, less missed; a several-month objective with months to go simply continues. With no key results, nothing: no suggestion.
  ObjectiveResult? get suggestedResult {
    if (suggestionKnown) return suggested;
    if (keyResults.isEmpty) return null;
    if (progress >= 100) return ObjectiveResult.achieved;
    if (span != null && !span!.isFinal) return ObjectiveResult.continued;
    return progress >= 50 ? ObjectiveResult.partly : ObjectiveResult.missed;
  }

  factory MonthlyObjective.fromJson(Map<String, dynamic> j) => MonthlyObjective(
        id: _s(j['id']),
        departmentId: _s(j['departmentId']),
        departmentName: _s(j['departmentName']),
        year: _i(j['year']),
        month: _i(j['month']),
        objective: _s(j['objective']),
        description: _s(j['description']),
        priority: _s(j['priority']).isEmpty ? 'medium' : _s(j['priority']),
        ownerId: j['ownerId'] == null ? null : _s(j['ownerId']),
        ownerName: _s(j['ownerName']),
        keyResults: _l(j['keyResults']).map(MonthlyKeyResult.fromJson).toList(),
        progress: _i(j['progress']),
        span: j['span'] is Map ? ObjectiveSpan.fromJson(_m(j['span'])) : null,
        suggested: ObjectiveResult.parse(j['suggestedResult']),
        suggestionKnown: j.containsKey('suggestedResult'),
        result: ObjectiveResult.parse(j['result']),
        resultNote: _s(j['resultNote']),
        closedAt: DateTime.tryParse(_s(j['closedAt']))?.toLocal(),
        progressAtClose: j['progressAtClose'] == null ? null : _i(j['progressAtClose']),
        overridden: j['overridden'] == true,
        planLocked: j['planLocked'] == true,
        readyToClose: j['readyToClose'] == true,
        assignedToMe: j['assignedToMe'] == true,
        changes: _l(j['changes']).map(ObjectiveChange.fromJson).toList(),
        carriedFrom: j['carriedFrom'] == true,
        carriedTo: j['carriedTo'] == true,
        updatedAt: _s(j['updatedAt']),
        access: ObjectiveAccess.fromJson(_m(j['access'])),
      );
}

class MonthlySummary {
  const MonthlySummary({
    this.count = 0,
    this.avgProgress = 0,
    this.open = 0,
    this.closed = 0,
    this.achieved = 0,
    this.partly = 0,
    this.missed = 0,
    this.continued = 0,
    this.cancelled = 0,
    this.deferred = 0,
  });
  final int count;
  final int avgProgress;
  final int open;
  final int closed;
  final int achieved;
  final int partly;
  final int missed;
  final int continued;
  final int cancelled;
  final int deferred;

  /// How many ended in [r].
  int of(ObjectiveResult r) => switch (r) {
        ObjectiveResult.achieved => achieved,
        ObjectiveResult.partly => partly,
        ObjectiveResult.missed => missed,
        ObjectiveResult.continued => continued,
        ObjectiveResult.cancelled => cancelled,
        ObjectiveResult.deferred => deferred,
      };

  factory MonthlySummary.fromJson(Map<String, dynamic> j) => MonthlySummary(
        count: _i(j['count']),
        avgProgress: _i(j['avgProgress']),
        open: _i(j['open']),
        closed: _i(j['closed']),
        achieved: _i(j['achieved']),
        partly: _i(j['partly']),
        missed: _i(j['missed']),
        continued: _i(j['continued']),
        cancelled: _i(j['cancelled']),
        deferred: _i(j['deferred']),
      );
}

/// One department's month: who leads it, what it has set, how it is going, and how last month ended.
class MonthlyDepartment {
  const MonthlyDepartment({
    required this.departmentId,
    required this.name,
    this.key = '',
    this.division = '',
    this.headName,
    this.canManage = false,
    this.isMine = false,
    this.objectives = const [],
    this.summary = const MonthlySummary(),
    this.lastMonth = const MonthlySummary(),
  });

  final String departmentId;
  final String name;
  final String key;
  final String division;
  final String? headName;
  final bool canManage;

  /// The viewer's own department — led or belonged to. Listed first.
  final bool isMine;
  final List<MonthlyObjective> objectives;
  final MonthlySummary summary;
  final MonthlySummary lastMonth;

  bool get isEmpty => objectives.isEmpty;

  factory MonthlyDepartment.fromJson(Map<String, dynamic> j) => MonthlyDepartment(
        departmentId: _s(j['departmentId']),
        name: _s(j['name']),
        key: _s(j['key']),
        division: _s(j['division']),
        headName: j['head'] is Map ? _s(_m(j['head'])['name']) : null,
        canManage: j['canManage'] == true,
        isMine: j['member'] == true,
        objectives: _l(j['objectives']).map(MonthlyObjective.fromJson).toList(),
        summary: MonthlySummary.fromJson(_m(j['summary'])),
        lastMonth: MonthlySummary.fromJson(_m(j['lastMonth'])),
      );
}

class MonthlyObjectivesPage {
  const MonthlyObjectivesPage({
    required this.year,
    required this.month,
    required this.isCurrent,
    required this.departments,
    this.assigned = const [],
    this.departmentCount = 0,
    this.withObjectives = 0,
    this.objectiveCount = 0,
    this.avgProgress = 0,
    this.closed = 0,
  });

  final int year;
  final int month;
  final bool isCurrent;
  final List<MonthlyDepartment> departments;

  /// What has been given to the viewer this month, from any department (even one they cannot otherwise see).
  final List<MonthlyObjective> assigned;
  final int departmentCount;
  final int withObjectives;
  final int objectiveCount;
  final int avgProgress;
  final int closed;

  MonthKey get key => (year: year, month: month);

  /// Departments that have set nothing for the month — a gap is shown, not hidden.
  List<MonthlyDepartment> get notSet => departments.where((d) => d.isEmpty).toList();

  factory MonthlyObjectivesPage.fromJson(Map<String, dynamic> j) {
    final t = _m(j['totals']);
    return MonthlyObjectivesPage(
      year: _i(j['year']),
      month: _i(j['month']),
      isCurrent: j['isCurrent'] == true,
      departments: _l(j['departments']).map(MonthlyDepartment.fromJson).toList(),
      assigned: _l(j['assigned']).map(MonthlyObjective.fromJson).toList(),
      departmentCount: _i(t['departments']),
      withObjectives: _i(t['withObjectives']),
      objectiveCount: _i(t['objectives']),
      avgProgress: _i(t['avgProgress']),
      closed: _i(t['closed']),
    );
  }
}
