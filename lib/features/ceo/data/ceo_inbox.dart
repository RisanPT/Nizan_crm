// The CEO home's two server payloads: GET /api/ceo/inbox and GET /api/ceo/signals (backend services/ceoInbox.js).
import 'package:nizan_crm/features/ceo/data/decision_models.dart';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
double? _dn(dynamic v) => (v as num?)?.toDouble();

/// One kind of thing that is waiting: the CEO's own decision ([isMine]), or an approval stuck with someone else.
class CeoInboxItem {
  const CeoInboxItem({
    required this.key,
    required this.label,
    required this.isMine,
    required this.count,
    this.withWhom,
    this.amount,
    this.oldestDays,
    this.route,
  });

  final String key;
  final String label;

  /// True: a decision for the CEO. False: waiting with the team (shown so a stuck approval is seen).
  final bool isMine;
  final int count;

  /// Who it is waiting with ("Accounts"), for the team's items.
  final String? withWhom;

  /// ₹ waiting, where the item has money on it.
  final double? amount;

  /// How long the oldest one has been waiting.
  final int? oldestDays;

  /// The screen to open, when the CEO can open one.
  final String? route;

  factory CeoInboxItem.fromJson(Map<String, dynamic> j) => CeoInboxItem(
        key: j['key']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        isMine: j['owner'] == 'you',
        count: _i(j['count']),
        withWhom: j['withWhom']?.toString(),
        amount: _dn(j['amount']),
        oldestDays: (j['oldestDays'] as num?)?.toInt(),
        route: (j['route']?.toString().isEmpty ?? true) ? null : j['route'].toString(),
      );

  /// Waiting long enough to be worth a nudge.
  bool get isStale => !isMine && (oldestDays ?? 0) >= 3;
}

class CeoInbox {
  const CeoInbox({
    required this.items,
    required this.needsYou,
    required this.withTeam,
    required this.oldestTeamDays,
    this.desk = const DecisionCounts(),
    this.preview = const [],
    this.recent = const [],
    this.logOpen = 0,
  });

  final List<CeoInboxItem> items;
  final int needsYou;
  final int withTeam;
  final int oldestTeamDays;

  /// The decision desk: how many requests wait (and what kind), the first few of them, and the last few decided.
  final DecisionCounts desk;
  final List<DecisionRequest> preview;
  final List<DecisionRequest> recent;

  /// Open entries in the manual decisions log.
  final int logOpen;

  List<CeoInboxItem> get mine => items.where((i) => i.isMine).toList();
  List<CeoInboxItem> get team => items.where((i) => !i.isMine).toList();
  bool get isEmpty => items.isEmpty;

  factory CeoInbox.fromJson(Map<String, dynamic> j) => CeoInbox(
        items: ((j['items'] as List?) ?? const []).map((e) => CeoInboxItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        needsYou: _i(j['needsYou']),
        withTeam: _i(j['withTeam']),
        oldestTeamDays: _i(j['oldestTeamDays']),
        desk: DecisionCounts.fromJson(j['decisions'] is Map ? Map<String, dynamic>.from(j['decisions'] as Map) : null),
        preview: (((j['decisions'] as Map?)?['preview'] as List?) ?? const []).map((e) => DecisionRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        recent: ((j['recent'] as List?) ?? const []).map((e) => DecisionRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        logOpen: _i((j['log'] as Map?)?['open']),
      );
}

enum CeoSeverity {
  ok,
  watch,
  alert;

  static CeoSeverity parse(String? s) => switch (s) {
        'alert' => CeoSeverity.alert,
        'watch' => CeoSeverity.watch,
        _ => CeoSeverity.ok,
      };
}

/// One line of the watch list.
class CeoSignal {
  const CeoSignal({required this.key, required this.label, required this.value, required this.severity, this.previous, this.route});

  final String key;
  final String label;
  final double value;

  /// The figure it is compared with (last month's cancellations, the previous 30 days' NPS), when there is one.
  final double? previous;
  final CeoSeverity severity;
  final String? route;

  factory CeoSignal.fromJson(Map<String, dynamic> j) => CeoSignal(
        key: j['key']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        value: (j['value'] as num?)?.toDouble() ?? 0,
        previous: _dn(j['previous']),
        severity: CeoSeverity.parse(j['severity']?.toString()),
        route: (j['route']?.toString().isEmpty ?? true) ? null : j['route'].toString(),
      );

  /// "−3 on last month" / "+8 on the 30 days before" — blank when there is nothing to compare with.
  String? get change {
    final p = previous;
    if (p == null) return null;
    final d = value - p;
    if (d == 0) return 'same as before';
    final n = d.abs() == d.abs().roundToDouble() ? d.abs().toStringAsFixed(0) : d.abs().toStringAsFixed(1);
    return '${d > 0 ? '+' : '−'}$n on before';
  }
}
