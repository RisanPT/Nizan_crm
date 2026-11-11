import 'consultation.dart';

/// One stylist's row in the team report.
class StylistReportRow {
  final String stylistId;
  final String name;
  final int total;
  final int scheduled;
  final int completed;
  final int cancelled;
  final int noShow;

  /// Completed ÷ (Completed + No-show); null until a consultation has ended.
  final double? attendedRate;

  const StylistReportRow({
    this.stylistId = '',
    this.name = '',
    this.total = 0,
    this.scheduled = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.noShow = 0,
    this.attendedRate,
  });

  factory StylistReportRow.fromJson(Map<String, dynamic> json) => StylistReportRow(
        stylistId: (json['stylistId'] ?? '').toString(),
        name: json['name'] as String? ?? '',
        total: (json['total'] as num?)?.toInt() ?? 0,
        scheduled: (json['scheduled'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
        noShow: (json['noShow'] as num?)?.toInt() ?? 0,
        attendedRate: (json['attendedRate'] as num?)?.toDouble(),
      );
}

/// A client with a pending follow-up.
class PendingFollowUp {
  final String leadId;
  final String name;
  final String phone;
  final DateTime? followUpDate;
  final bool overdue;

  const PendingFollowUp({
    this.leadId = '',
    this.name = '',
    this.phone = '',
    this.followUpDate,
    this.overdue = false,
  });

  factory PendingFollowUp.fromJson(Map<String, dynamic> json) => PendingFollowUp(
        leadId: (json['leadId'] ?? '').toString(),
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        followUpDate: DateTime.tryParse(json['followUpDate'] as String? ?? '')?.toLocal(),
        overdue: json['overdue'] as bool? ?? false,
      );
}

/// Dashboard + operational report (SRS FR-13) for a date range.
class ConsultationSummary {
  final String from;
  final String to;

  /// 'all' for a stylist lead looking at the whole team, 'own' otherwise.
  final String scope;
  final Map<String, int> statusCounts;
  final List<StylistReportRow> perStylist;

  /// Enquiries per SRS client status, in report order.
  final Map<String, int> enquiryStatus;
  final List<Consultation> today;
  final List<Consultation> upcoming;
  final List<Consultation> needsOutcome;
  final int followUpCount;
  final List<PendingFollowUp> followUps;

  /// Active client files in scope (the stylist's own, or the whole team).
  final int activeClients;

  const ConsultationSummary({
    this.from = '',
    this.to = '',
    this.scope = 'own',
    this.statusCounts = const {},
    this.perStylist = const [],
    this.enquiryStatus = const {},
    this.today = const [],
    this.upcoming = const [],
    this.needsOutcome = const [],
    this.followUpCount = 0,
    this.followUps = const [],
    this.activeClients = 0,
  });

  bool get isTeam => scope == 'all';

  int count(String status) => statusCounts[status] ?? 0;
  int get total => statusCounts['total'] ?? 0;

  static Map<String, int> _counts(dynamic raw) => {
        if (raw is Map)
          for (final e in raw.entries) '${e.key}': (e.value as num?)?.toInt() ?? 0,
      };

  static List<Consultation> _consultations(dynamic raw) => ((raw as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(Consultation.fromJson)
      .toList();

  factory ConsultationSummary.fromJson(Map<String, dynamic> json) {
    final range = json['range'] as Map? ?? const {};
    final followUps = json['followUps'] as Map? ?? const {};
    return ConsultationSummary(
      from: range['from'] as String? ?? '',
      to: range['to'] as String? ?? '',
      scope: json['scope'] as String? ?? 'own',
      statusCounts: _counts(json['statusCounts']),
      perStylist: ((json['perStylist'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StylistReportRow.fromJson)
          .toList(),
      enquiryStatus: _counts(json['enquiryStatus']),
      today: _consultations(json['today']),
      upcoming: _consultations(json['upcoming']),
      needsOutcome: _consultations(json['needsOutcome']),
      followUpCount: (followUps['count'] as num?)?.toInt() ?? 0,
      activeClients: (json['activeClients'] as num?)?.toInt() ?? 0,
      followUps: ((followUps['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PendingFollowUp.fromJson)
          .toList(),
    );
  }
}
