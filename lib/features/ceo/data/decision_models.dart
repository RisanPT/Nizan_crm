// The CEO / Executive Director's decision desk — the server's payloads (backend services/decisions.js, utils/decisionRules.js).
// A "request" is something the team has checked that waits for a leader: a project proposal, a hiring plan, a big expense or payout,
// or a project budget increase.

double? _dn(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
String _s(dynamic v) => v?.toString() ?? '';

enum DecisionKind {
  projectProposal('project_proposal', 'Project proposal'),
  hiringPlan('hiring_plan', 'Hiring plan'),
  spendExpense('spend_expense', 'Department expense'),
  spendPayout('spend_payout', 'Artist payout'),
  projectBudget('project_budget', 'Project budget');

  const DecisionKind(this.wire, this.label);
  final String wire;
  final String label;

  static DecisionKind parse(String? s) => DecisionKind.values.firstWhere((k) => k.wire == s, orElse: () => DecisionKind.spendExpense);
}

/// How a request stands. `pending` / `deferred` are open (a leader still has to decide); the rest are settled.
enum DecisionStatus {
  pending,
  deferred,
  approved,
  rejected,
  withdrawn,
  superseded;

  static DecisionStatus parse(String? s) => DecisionStatus.values.firstWhere((v) => v.name == s, orElse: () => DecisionStatus.pending);
  bool get isOpen => this == pending || this == deferred;
}

/// What a leader does with a request.
enum DecisionAction {
  approve('approve'),
  reject('reject'),
  defer('defer');

  const DecisionAction(this.wire);
  final String wire;
}

class DecisionPerson {
  const DecisionPerson({required this.name, this.id = '', this.role = '', this.label = ''});

  final String id;
  final String name;
  final String role;

  /// For a team check: who it was ("Accounts", "HR", "the finance head").
  final String label;

  factory DecisionPerson.fromJson(Map<String, dynamic> j) => DecisionPerson(id: _s(j['id']), name: _s(j['name']), role: _s(j['role']), label: _s(j['label']));

  /// "CEO" / "Executive Director" for a leader; blank for anyone else.
  String get title => switch (role) {
        'ceo' => 'CEO',
        'executive_director' => 'Executive Director',
        _ => '',
      };

  /// "Anita (CEO)".
  String get nameWithTitle => title.isEmpty ? name : '$name ($title)';
}

/// Who decided, when and why.
class DecisionOutcome {
  const DecisionOutcome({required this.by, this.at, this.note = ''});

  final DecisionPerson by;
  final DateTime? at;
  final String note;

  factory DecisionOutcome.fromJson(Map<String, dynamic> j) =>
      DecisionOutcome(by: DecisionPerson.fromJson(Map<String, dynamic>.from(j['by'] as Map? ?? const {})), at: _dt(j['at']), note: _s(j['note']));
}

class DecisionRow {
  const DecisionRow(this.label, this.value);
  final String label;
  final String value;
}

class DecisionEvent {
  const DecisionEvent({required this.action, this.at, this.by, this.note = ''});
  final String action;
  final DateTime? at;
  final DecisionPerson? by;
  final String note;
}

class DecisionRequest {
  const DecisionRequest({
    required this.id,
    required this.kind,
    required this.status,
    required this.title,
    this.subtitle = '',
    this.department = '',
    this.amount,
    this.previousAmount,
    this.requestedBy,
    this.requestedAt,
    this.checkedBy,
    this.checkedAt,
    this.checkNote = '',
    this.waitingDays = 0,
    this.deferredUntil,
    this.decision,
    this.summary = const [],
    this.attachments = const [],
    this.sourceRoute,
    this.applyError = '',
    this.canDecide = false,
    this.history = const [],
  });

  final String id;
  final DecisionKind kind;
  final DecisionStatus status;
  final String title;
  final String subtitle;
  final String department;
  final double? amount;
  final double? previousAmount;
  final DecisionPerson? requestedBy;
  final DateTime? requestedAt;

  /// The team's check before it came here (null for a proposal, which nobody checks).
  final DecisionPerson? checkedBy;
  final DateTime? checkedAt;
  final String checkNote;
  final int waitingDays;
  final DateTime? deferredUntil;
  final DecisionOutcome? decision;
  final List<DecisionRow> summary;
  final List<DecisionRow> attachments; // label → url
  final String? sourceRoute;
  final String applyError;
  final bool canDecide;
  final List<DecisionEvent> history;

  bool get isOpen => status.isOpen;

  /// Put off to a date that has not come yet.
  bool get isDeferredNow => status == DecisionStatus.deferred && deferredUntil != null && deferredUntil!.isAfter(DateTime.now());

  /// "Verified by Accounts (Dev) · 2 d" — blank when nobody checked it.
  String get checkedLine {
    final c = checkedBy;
    if (c == null) return '';
    final who = c.label.isNotEmpty ? '${c.label} (${c.name})' : c.name;
    return 'Verified by $who';
  }

  factory DecisionRequest.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
    final checked = m(j['checkedBy']);
    final requested = m(j['requestedBy']);
    final decided = m(j['decision']);
    return DecisionRequest(
      id: _s(j['id']),
      kind: DecisionKind.parse(_s(j['kind'])),
      status: DecisionStatus.parse(_s(j['status'])),
      title: _s(j['title']),
      subtitle: _s(j['subtitle']),
      department: _s(j['department']),
      amount: _dn(j['amount']),
      previousAmount: _dn(j['previousAmount']),
      requestedBy: requested == null ? null : DecisionPerson.fromJson(requested),
      requestedAt: _dt(j['requestedAt']),
      checkedBy: checked == null ? null : DecisionPerson.fromJson(checked),
      checkedAt: _dt(j['checkedAt']),
      checkNote: _s(j['checkNote']),
      waitingDays: _i(j['waitingDays']),
      deferredUntil: _dt(j['deferredUntil']),
      decision: decided == null ? null : DecisionOutcome.fromJson(decided),
      summary: ((j['summary'] as List?) ?? const []).map((e) => DecisionRow(_s((e as Map)['label']), _s(e['value']))).toList(),
      attachments: ((j['attachments'] as List?) ?? const []).map((e) => DecisionRow(_s((e as Map)['label']), _s(e['url']))).toList(),
      sourceRoute: _s(j['sourceRoute']).isEmpty ? null : _s(j['sourceRoute']),
      applyError: _s(j['applyError']),
      canDecide: j['canDecide'] == true && DecisionStatus.parse(_s(j['status'])).isOpen, // never on a settled one
      history: ((j['history'] as List?) ?? const [])
          .map((e) {
            final h = Map<String, dynamic>.from(e as Map);
            final by = m(h['by']);
            return DecisionEvent(action: _s(h['action']), at: _dt(h['at']), by: by == null ? null : DecisionPerson.fromJson(by), note: _s(h['note']));
          })
          .toList(),
    );
  }
}

/// The counts on the leaders' desk. [pending] excludes what was put off to a later date.
class DecisionCounts {
  const DecisionCounts({this.open = 0, this.pending = 0, this.deferred = 0, this.byKind = const {}, this.oldestDays = 0});

  final int open;
  final int pending;
  final int deferred;
  final Map<String, int> byKind;
  final int oldestDays;

  factory DecisionCounts.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const DecisionCounts();
    return DecisionCounts(
      open: _i(j['open']),
      pending: _i(j['pending']),
      deferred: _i(j['deferred']),
      byKind: {for (final e in ((j['byKind'] as Map?) ?? const {}).entries) e.key.toString(): _i(e.value)},
      oldestDays: _i(j['oldestDays']),
    );
  }
}

class DecisionQueue {
  const DecisionQueue({required this.items, this.nextCursor, this.counts = const DecisionCounts()});
  final List<DecisionRequest> items;
  final String? nextCursor;
  final DecisionCounts counts;

  factory DecisionQueue.fromJson(Map<String, dynamic> j) => DecisionQueue(
        items: ((j['items'] as List?) ?? const []).map((e) => DecisionRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        nextCursor: j['nextCursor']?.toString(),
        counts: DecisionCounts.fromJson(j['counts'] is Map ? Map<String, dynamic>.from(j['counts'] as Map) : null),
      );
}

/// What reaches the leaders, set by hand (Decision rules). A blank limit is off.
class DecisionPolicy {
  const DecisionPolicy({
    this.expense,
    this.payout,
    this.projectBudget,
    this.hiringPlansNeedLeadership = false,
    this.on = false,
    this.summary = '',
    this.updatedByName = '',
    this.updatedAt,
    this.canEdit = false,
    this.hasLeadership = true,
    this.history = const [],
  });

  final double? expense;
  final double? payout;
  final double? projectBudget;
  final bool hiringPlansNeedLeadership;
  final bool on;
  final String summary;
  final String updatedByName;
  final DateTime? updatedAt;
  final bool canEdit;

  /// False when there is no CEO / Executive Director login: nothing can be switched on.
  final bool hasLeadership;
  final List<({DateTime? at, String byName})> history;

  factory DecisionPolicy.fromJson(Map<String, dynamic> j) {
    final limits = j['spendLimits'] is Map ? Map<String, dynamic>.from(j['spendLimits'] as Map) : const <String, dynamic>{};
    return DecisionPolicy(
      expense: _dn(limits['expense']),
      payout: _dn(limits['payout']),
      projectBudget: _dn(limits['projectBudget']),
      hiringPlansNeedLeadership: j['hiringPlansNeedLeadership'] == true,
      on: j['on'] == true,
      summary: _s(j['summary']),
      updatedByName: _s(j['updatedByName']),
      updatedAt: _dt(j['updatedAt']),
      canEdit: j['canEdit'] == true,
      hasLeadership: j['hasLeadership'] != false,
      history: ((j['history'] as List?) ?? const []).map((e) => (at: _dt((e as Map)['at']), byName: _s(e['byName']))).toList(),
    );
  }
}

/// A decision the server refused: somebody else decided first (409 ALREADY_DECIDED), or the item changed (409 SOURCE_CHANGED), or a
/// bad request (400). [message] is fit to show as it is.
class DecisionConflict implements Exception {
  const DecisionConflict({required this.code, required this.message, this.status = 409, this.decision, this.field});

  final String code;
  final String message;
  final int status;
  final DecisionOutcome? decision;
  final String? field;

  /// Somebody else already settled it — the card should turn into a decided card.
  bool get isSettled => code == 'ALREADY_DECIDED' || code == 'SOURCE_CHANGED' || code == 'NOT_FOUND';

  @override
  String toString() => message;
}
