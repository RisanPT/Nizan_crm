// ApprovalRequest model — mirrors backend/models/ApprovalRequest.js. Drives the
// generic HR Approvals inbox (leave, regularization, reimbursement, travel…).

DateTime? _date(dynamic v) =>
    (v == null) ? null : DateTime.tryParse(v.toString());
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

class ApprovalStep {
  final int level;
  final String label;
  final String approverRole;
  final String state; // pending | approved | rejected | skipped
  final String note;
  final DateTime? decidedAt;

  const ApprovalStep({
    this.level = 0,
    this.label = '',
    this.approverRole = '',
    this.state = 'pending',
    this.note = '',
    this.decidedAt,
  });

  factory ApprovalStep.fromJson(Map<String, dynamic> j) => ApprovalStep(
        level: _i(j['level']),
        label: j['label'] as String? ?? '',
        approverRole: j['approverRole'] as String? ?? '',
        state: j['state'] as String? ?? 'pending',
        note: j['note'] as String? ?? '',
        decidedAt: _date(j['decidedAt']),
      );
}

class ApprovalRequest {
  final String id;
  final String module; // leave | regularization | reimbursement | travel | …
  final String title;
  final String summary;
  final String requesterName;
  final String requesterDepartment;
  final double amount;
  final String status; // pending | approved | rejected | cancelled
  final int currentLevel;
  final List<ApprovalStep> chain;
  final String link;
  final String refId;
  final String refModel;
  final DateTime? createdAt;

  const ApprovalRequest({
    required this.id,
    required this.module,
    this.title = '',
    this.summary = '',
    this.requesterName = '',
    this.requesterDepartment = '',
    this.amount = 0,
    this.status = 'pending',
    this.currentLevel = 0,
    this.chain = const [],
    this.link = '',
    this.refId = '',
    this.refModel = '',
    this.createdAt,
  });

  String get currentStepLabel =>
      (currentLevel >= 0 && currentLevel < chain.length)
          ? chain[currentLevel].label
          : '';

  factory ApprovalRequest.fromJson(Map<String, dynamic> j) {
    final req = j['requesterEmployeeId'];
    final reqMap = req is Map<String, dynamic> ? req : null;
    return ApprovalRequest(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      module: j['module'] as String? ?? 'other',
      title: j['title'] as String? ?? '',
      summary: j['summary'] as String? ?? '',
      requesterName: reqMap?['name'] as String? ?? '',
      requesterDepartment: reqMap?['department'] as String? ?? '',
      amount: _d(j['amount']),
      status: j['status'] as String? ?? 'pending',
      currentLevel: _i(j['currentLevel']),
      chain: ((j['chain'] as List?) ?? const [])
          .map((e) => ApprovalStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      link: j['link'] as String? ?? '',
      refId: (j['refId'] is Map ? (j['refId']['_id'] ?? '') : (j['refId'] ?? '')).toString(),
      refModel: j['refModel'] as String? ?? '',
      createdAt: _date(j['createdAt']),
    );
  }
}
