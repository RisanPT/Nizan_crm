// The CRM team's work, as the server sends it (backend /api/crm — controllers/crmController.js, services/crmMetrics.js).
// A figure the server could not know comes as null and is shown as "—", never 0.

Map<String, dynamic> _map(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};
List<Map<String, dynamic>> _list(Object? v) => v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];
String _s(Object? v) => v == null ? '' : v.toString();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
num? _n(Object? v) => v is num ? v : (v is String ? num.tryParse(v) : null);
DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
String? _id(Object? v) {
  if (v == null) return null;
  if (v is Map) return _s(v['_id'] ?? v['id']);
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// Who is looking: 'admin' (management), 'head' (the CRM Head), 'member', 'leadership' (CEO / Executive Director, read-only).
class CrmMe {
  final String viewer;
  final String userId;
  final String name;
  final bool canAssign;
  final bool seesTeam;
  final bool canWrite;
  final bool onTeam;
  final DateTime? trackingSince;
  final CrmSettings settings;
  const CrmMe({
    required this.viewer,
    required this.userId,
    this.name = '',
    this.canAssign = false,
    this.seesTeam = false,
    this.canWrite = false,
    this.onTeam = false,
    this.trackingSince,
    this.settings = const CrmSettings(),
  });

  bool get isHead => viewer == 'head';

  factory CrmMe.fromJson(Map<String, dynamic> j) => CrmMe(
    viewer: _s(j['viewer']),
    userId: _s(j['userId']),
    name: _s(j['name']),
    canAssign: j['canAssign'] == true,
    seesTeam: j['seesTeam'] == true,
    canWrite: j['canWrite'] == true,
    onTeam: j['onTeam'] == true,
    trackingSince: _d(j['trackingSince']),
    settings: CrmSettings.fromJson(_map(j['settings'])),
  );
}

/// The CRM team's time limits and thresholds (backend models/CrmSettings.js).
class CrmSettings {
  final int requestSlaHours;
  final int chatResponseSlaMins;
  final int chatUnansweredHours;
  final Map<String, int> caseSlaHours;
  final num lowNps;
  final int trialConversionDays;
  final int reEngagementWinDays;
  final int monthlyCustomerTarget;
  final DateTime? trackingSince;
  final String updatedByName;
  const CrmSettings({
    this.requestSlaHours = 24,
    this.chatResponseSlaMins = 60,
    this.chatUnansweredHours = 4,
    this.caseSlaHours = const {'complaint': 48, 'follow_up': 72, 're_engagement': 168, 'trial_follow_up': 72},
    this.lowNps = 6,
    this.trialConversionDays = 60,
    this.reEngagementWinDays = 90,
    this.monthlyCustomerTarget = 100,
    this.trackingSince,
    this.updatedByName = '',
  });

  factory CrmSettings.fromJson(Map<String, dynamic> j) => CrmSettings(
    requestSlaHours: _i(j['requestSlaHours'] ?? 24),
    chatResponseSlaMins: _i(j['chatResponseSlaMins'] ?? 60),
    chatUnansweredHours: _i(j['chatUnansweredHours'] ?? 4),
    caseSlaHours: {for (final e in _map(j['caseSlaHours']).entries) e.key: _i(e.value)},
    lowNps: _n(j['lowNps']) ?? 6,
    trialConversionDays: _i(j['trialConversionDays'] ?? 60),
    reEngagementWinDays: _i(j['reEngagementWinDays'] ?? 90),
    monthlyCustomerTarget: _i(j['monthlyCustomerTarget'] ?? 100),
    trackingSince: _d(j['trackingSince']),
    updatedByName: _s(j['updatedByName']),
  );
}

/// One dashboard figure: this period, the period before, how many records it rests on, and which way is good.
class CrmKpi {
  final num? value;
  final num? prev;
  final int? n;
  final String unit; // count | pct | hours | mins | score | rating
  final String better; // up | down
  const CrmKpi({this.value, this.prev, this.n, this.unit = 'count', this.better = 'up'});

  factory CrmKpi.fromJson(Map<String, dynamic> j) =>
      CrmKpi(value: _n(j['value']), prev: _n(j['prev']), n: j['n'] == null ? null : _i(j['n']), unit: _s(j['unit']).isEmpty ? 'count' : _s(j['unit']), better: _s(j['better']).isEmpty ? 'up' : _s(j['better']));

  /// The figure as it reads: "12", "66.7%", "9 h", "105 min", "4.5 / 5" — "—" when it cannot be known.
  String get display => formatCrmFigure(value, unit);

  /// Change from the previous period: null when either side is unknown or nothing changed.
  num? get change => (value == null || prev == null || value == prev) ? null : value! - prev!;

  /// Was the change for the better (true), worse (false), or neither (null)?
  bool? get improved {
    final c = change;
    if (c == null) return null;
    return (c > 0) == (better == 'up');
  }

  /// "+3 vs before", "−12.5 pts vs before" — or null.
  String? get changeText {
    final c = change;
    if (c == null) return null;
    final abs = _trim(c.abs());
    final sign = c > 0 ? '+' : '−';
    final unitText = switch (unit) {
      'pct' => ' pts',
      'hours' => ' h',
      'mins' => ' min',
      _ => '',
    };
    return '$sign$abs$unitText vs before';
  }
}

String _trim(num v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1);
}

/// A CRM figure as it reads (the same wording as the downloaded report — backend utils/crmReportRows.js formatKpi).
String formatCrmFigure(num? value, String unit) {
  if (value == null) return '—';
  final v = _trim(value);
  return switch (unit) {
    'pct' => '$v%',
    'hours' => '$v h',
    'mins' => '$v min',
    'rating' => '$v / 5',
    _ => v,
  };
}

/// Open work, per person or in total.
class CrmWorkload {
  final int requests, chats, cases, trials, overdue, total;
  const CrmWorkload({this.requests = 0, this.chats = 0, this.cases = 0, this.trials = 0, this.overdue = 0, this.total = 0});
  factory CrmWorkload.fromJson(Map<String, dynamic> j) =>
      CrmWorkload(requests: _i(j['requests']), chats: _i(j['chats']), cases: _i(j['cases']), trials: _i(j['trials']), overdue: _i(j['overdue']), total: _i(j['total']));
}

class CrmTrendPoint {
  final String key; // 'YYYY-MM-DD' or 'YYYY-MM'
  final int? requestsReceived, requestsDecided, chatWaits, chatAnswered, casesOpened, casesResolved;
  const CrmTrendPoint({required this.key, this.requestsReceived, this.requestsDecided, this.chatWaits, this.chatAnswered, this.casesOpened, this.casesResolved});
  static int? _o(Object? v) => v == null ? null : _i(v);
  factory CrmTrendPoint.fromJson(Map<String, dynamic> j) => CrmTrendPoint(
    key: _s(j['key']),
    requestsReceived: _o(j['requestsReceived']),
    requestsDecided: _o(j['requestsDecided']),
    chatWaits: _o(j['chatWaits']),
    chatAnswered: _o(j['chatAnswered']),
    casesOpened: _o(j['casesOpened']),
    casesResolved: _o(j['casesResolved']),
  );
}

class CrmMemberLine {
  final String userId;
  final String name;
  final bool isHead;
  final CrmWorkload workload;
  final Map<String, CrmKpi> kpis;
  const CrmMemberLine({required this.userId, required this.name, this.isHead = false, this.workload = const CrmWorkload(), this.kpis = const {}});
  factory CrmMemberLine.fromJson(Map<String, dynamic> j) => CrmMemberLine(
    userId: _s(j['userId']),
    name: _s(j['name']),
    isHead: j['isHead'] == true,
    workload: CrmWorkload.fromJson(_map(j['workload'])),
    kpis: {for (final e in _map(j['kpis']).entries) e.key: CrmKpi.fromJson(_map(e.value))},
  );
  CrmKpi kpi(String key) => kpis[key] ?? const CrmKpi();
}

/// The CRM dashboard for a period (GET /api/crm/overview).
class CrmOverview {
  final String from, to, label;
  final String? previousFrom, previousTo;
  final bool isTeam;
  final String memberName;
  final DateTime? trackingSince;
  final bool partial;
  final Map<String, CrmKpi> kpis;
  final CrmWorkload now;
  final CrmWorkload? unassigned;
  final List<CrmTrendPoint> trend;
  final List<CrmMemberLine> members;
  final List<CrmQueueItem> breaches;
  final int breachCount;
  final CrmSettings settings;

  /// The newest things that happened (requests in and decided, chats, cases, reviews) — the dashboard's Recent activities.
  final List<CrmFeedItem> recent;

  /// The next trials from today, soonest first.
  final List<CrmUpcomingTrial> upcomingTrials;
  const CrmOverview({
    required this.from,
    required this.to,
    this.label = '',
    this.previousFrom,
    this.previousTo,
    this.isTeam = true,
    this.memberName = '',
    this.trackingSince,
    this.partial = false,
    this.kpis = const {},
    this.now = const CrmWorkload(),
    this.unassigned,
    this.trend = const [],
    this.members = const [],
    this.breaches = const [],
    this.breachCount = 0,
    this.settings = const CrmSettings(),
    this.recent = const [],
    this.upcomingTrials = const [],
  });

  CrmKpi kpi(String key) => kpis[key] ?? const CrmKpi();

  factory CrmOverview.fromJson(Map<String, dynamic> j) {
    final range = _map(j['range']);
    final prev = j['previous'] is Map ? _map(j['previous']) : null;
    final scope = _map(j['scope']);
    return CrmOverview(
      from: _s(range['from']),
      to: _s(range['to']),
      label: _s(range['label']),
      previousFrom: prev == null ? null : _s(prev['from']),
      previousTo: prev == null ? null : _s(prev['to']),
      isTeam: _s(scope['kind']) != 'member',
      memberName: _s(scope['name']),
      trackingSince: _d(j['trackingSince']),
      partial: j['partial'] == true,
      kpis: {for (final e in _map(j['kpis']).entries) e.key: CrmKpi.fromJson(_map(e.value))},
      now: CrmWorkload.fromJson(_map(j['now'])),
      unassigned: j['unassigned'] is Map ? CrmWorkload.fromJson(_map(j['unassigned'])) : null,
      trend: _list(j['trend']).map(CrmTrendPoint.fromJson).toList(),
      members: _list(j['members']).map(CrmMemberLine.fromJson).toList(),
      breaches: _list(j['breaches']).map(CrmQueueItem.fromJson).toList(),
      breachCount: _i(j['breachCount']),
      settings: CrmSettings.fromJson(_map(j['settings'])),
      recent: _list(j['recent']).map(CrmFeedItem.fromJson).toList(),
      upcomingTrials: _list(j['upcomingTrials']).map(CrmUpcomingTrial.fromJson).toList(),
    );
  }
}

/// One line of the dashboard's Recent activities: what happened, when, and (for a case) its status as a tag.
class CrmFeedItem {
  final String kind; // request | decided | chat | case | review
  final DateTime? at;
  final String text, tag, refType, refId;
  const CrmFeedItem({required this.kind, this.at, this.text = '', this.tag = '', this.refType = '', this.refId = ''});
  factory CrmFeedItem.fromJson(Map<String, dynamic> j) => CrmFeedItem(kind: _s(j['kind']), at: _d(j['at']), text: _s(j['text']), tag: _s(j['tag']), refType: _s(j['refType']), refId: _s(j['refId']));
}

/// A trial coming up: the package (or look) tried, the client, the day (YYYY-MM-DD) and start time, the artists. No phone number.
class CrmUpcomingTrial {
  final String id, trialNumber, clientName, what, date, startTime, status, owner;
  final List<String> artists;
  const CrmUpcomingTrial({required this.id, this.trialNumber = '', this.clientName = '', this.what = 'Trial', this.date = '', this.startTime = '', this.status = 'scheduled', this.owner = '', this.artists = const []});
  factory CrmUpcomingTrial.fromJson(Map<String, dynamic> j) => CrmUpcomingTrial(
    id: _s(j['id']),
    trialNumber: _s(j['trialNumber']),
    clientName: _s(j['clientName']),
    what: _s(j['what']).isEmpty ? 'Trial' : _s(j['what']),
    date: _s(j['date']),
    startTime: _s(j['startTime']),
    status: _s(j['status']).isEmpty ? 'scheduled' : _s(j['status']),
    owner: _s(j['owner']),
    artists: j['artists'] is List ? (j['artists'] as List).map(_s).where((x) => x.isNotEmpty).toList() : const [],
  );
}

/// One piece of open work: a booking request, a chat waiting for an answer, an open case or a trial to report on.
class CrmQueueItem {
  final String type; // booking | conversation | case | trial
  final String id;
  final String title;
  final String subtitle;
  final String phone;
  final String? ownerId;
  final String ownerName;
  final DateTime? since;
  final DateTime? dueAt;
  final bool overdue;
  final String status;
  final String link;
  const CrmQueueItem({
    required this.type,
    required this.id,
    this.title = '',
    this.subtitle = '',
    this.phone = '',
    this.ownerId,
    this.ownerName = '',
    this.since,
    this.dueAt,
    this.overdue = false,
    this.status = '',
    this.link = '',
  });

  bool get isAssigned => ownerId != null && ownerId!.isNotEmpty;

  String get typeLabel => switch (type) {
    'booking' => 'Booking request',
    'conversation' => 'Client chat',
    'case' => 'Case',
    'trial' => 'Trial',
    _ => type,
  };

  factory CrmQueueItem.fromJson(Map<String, dynamic> j) => CrmQueueItem(
    type: _s(j['type']),
    id: _s(j['id']),
    title: _s(j['title']),
    subtitle: _s(j['subtitle']),
    phone: _s(j['phone']),
    ownerId: _id(j['ownerId']),
    ownerName: _s(j['ownerName']),
    since: _d(j['since']),
    dueAt: _d(j['dueAt']),
    overdue: j['overdue'] == true,
    status: _s(j['status']),
    link: _s(j['link']),
  );
}

class CrmQueue {
  final List<CrmQueueItem> items;
  final Map<String, int> counts;
  const CrmQueue({this.items = const [], this.counts = const {}});
  factory CrmQueue.fromJson(Map<String, dynamic> j) =>
      CrmQueue(items: _list(j['items']).map(CrmQueueItem.fromJson).toList(), counts: {for (final e in _map(j['counts']).entries) e.key: _i(e.value)});
}

class CrmTeamMember {
  final String userId;
  final String name;
  final bool isHead;
  final CrmWorkload workload;
  const CrmTeamMember({required this.userId, required this.name, this.isHead = false, this.workload = const CrmWorkload()});
  factory CrmTeamMember.fromJson(Map<String, dynamic> j) =>
      CrmTeamMember(userId: _s(j['userId']), name: _s(j['name']), isHead: j['isHead'] == true, workload: CrmWorkload.fromJson(_map(j['workload'])));
}

class CrmTeam {
  final List<CrmTeamMember> members;
  final CrmWorkload unassigned;
  final List<CrmTeamMember> elsewhere;
  const CrmTeam({this.members = const [], this.unassigned = const CrmWorkload(), this.elsewhere = const []});
  factory CrmTeam.fromJson(Map<String, dynamic> j) => CrmTeam(
    members: _list(j['members']).map(CrmTeamMember.fromJson).toList(),
    unassigned: CrmWorkload.fromJson(_map(j['unassigned'])),
    elsewhere: _list(j['elsewhere']).map(CrmTeamMember.fromJson).toList(),
  );
}

/// What happened on a case: a call, a WhatsApp, a note, a status change, an assignment.
class CrmActivity {
  final String type;
  final String text;
  final String outcome;
  final DateTime? at;
  final String byName;
  const CrmActivity({required this.type, this.text = '', this.outcome = '', this.at, this.byName = ''});
  factory CrmActivity.fromJson(Map<String, dynamic> j) =>
      CrmActivity(type: _s(j['type']), text: _s(j['text']), outcome: _s(j['outcome']), at: _d(j['at']), byName: _s(j['byName']));
}

const crmCaseKinds = ['complaint', 'follow_up', 're_engagement', 'trial_follow_up'];
const crmCaseOutcomes = ['resolved', 'compensated', 'unresolved', 'won', 'not_interested', 'referral'];

String crmCaseKindLabel(String k) => switch (k) {
  'complaint' => 'Complaint',
  'follow_up' => 'Follow-up',
  're_engagement' => 'Re-engagement call',
  'trial_follow_up' => 'Trial follow-up',
  _ => k,
};

String crmCaseStatusLabel(String s) => switch (s) {
  'open' => 'Open',
  'in_progress' => 'In progress',
  'resolved' => 'Resolved',
  'closed' => 'Closed',
  _ => s,
};

String crmOutcomeLabel(String o) => o.isEmpty ? '' : '${o[0].toUpperCase()}${o.substring(1).replaceAll('_', ' ')}';

/// A complaint, follow-up, re-engagement call or trial follow-up (backend models/CrmCase.js).
class CrmCase {
  final String id;
  final String caseNumber;
  final String kind;
  final String title;
  final String description;
  final String priority;
  final String customerName;
  final String phone;
  final String? bookingId, reviewId, trialId, conversationId;
  final String origin;
  final String? ownerId;
  final String ownerName;
  final String status;
  final DateTime? dueAt;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final String resolvedByName;
  final String resolutionNote;
  final String outcome;
  final bool overdue;
  final List<CrmActivity> activities;
  const CrmCase({
    required this.id,
    this.caseNumber = '',
    this.kind = 'complaint',
    this.title = '',
    this.description = '',
    this.priority = 'normal',
    this.customerName = '',
    this.phone = '',
    this.bookingId,
    this.reviewId,
    this.trialId,
    this.conversationId,
    this.origin = '',
    this.ownerId,
    this.ownerName = '',
    this.status = 'open',
    this.dueAt,
    this.createdAt,
    this.resolvedAt,
    this.closedAt,
    this.resolvedByName = '',
    this.resolutionNote = '',
    this.outcome = '',
    this.overdue = false,
    this.activities = const [],
  });

  bool get isOpen => status == 'open' || status == 'in_progress';
  String get kindLabel => crmCaseKindLabel(kind);
  String get statusLabel => crmCaseStatusLabel(status);
  String get displayName => customerName.isNotEmpty ? customerName : title;

  factory CrmCase.fromJson(Map<String, dynamic> j) => CrmCase(
    id: _s(j['id'] ?? j['_id']),
    caseNumber: _s(j['caseNumber']),
    kind: _s(j['kind']),
    title: _s(j['title']),
    description: _s(j['description']),
    priority: _s(j['priority']).isEmpty ? 'normal' : _s(j['priority']),
    customerName: _s(j['customerName']),
    phone: _s(j['phone']),
    bookingId: _id(j['bookingId']),
    reviewId: _id(j['reviewId']),
    trialId: _id(j['trialId']),
    conversationId: _id(j['conversationId']),
    origin: _s(j['origin']),
    ownerId: _id(j['ownerId']),
    ownerName: _s(j['ownerName']),
    status: _s(j['status']).isEmpty ? 'open' : _s(j['status']),
    dueAt: _d(j['dueAt']),
    createdAt: _d(j['createdAt']),
    resolvedAt: _d(j['resolvedAt']),
    closedAt: _d(j['closedAt']),
    resolvedByName: _s(j['resolvedByName']),
    resolutionNote: _s(j['resolutionNote']),
    outcome: _s(j['outcome']),
    overdue: j['overdue'] == true,
    activities: _list(j['activities']).map(CrmActivity.fromJson).toList(),
  );
}

class CrmCasePage {
  final List<CrmCase> items;
  final int page, totalPages, totalItems;
  final Map<String, int> counts;
  const CrmCasePage({this.items = const [], this.page = 1, this.totalPages = 1, this.totalItems = 0, this.counts = const {}});
  factory CrmCasePage.fromJson(Map<String, dynamic> j) => CrmCasePage(
    items: _list(j['items']).map(CrmCase.fromJson).toList(),
    page: _i(j['page'] ?? 1),
    totalPages: _i(j['totalPages'] ?? 1),
    totalItems: _i(j['totalItems']),
    counts: {for (final e in _map(j['counts']).entries) e.key: _i(e.value)},
  );
}

/// A past client due a call (GET /api/crm/re-engagement).
class ReEngagementClient {
  final String customerName;
  final String phone;
  final String phoneKey;
  final String service;
  final DateTime? lastEventDate;
  final String? lastBookingId;
  final int bookings;
  final int monthsSince;
  final String? openCaseId;
  final String openCaseOwner;
  final String lastOutcome;
  final DateTime? lastOutcomeAt;
  const ReEngagementClient({
    required this.phoneKey,
    this.customerName = '',
    this.phone = '',
    this.service = '',
    this.lastEventDate,
    this.lastBookingId,
    this.bookings = 0,
    this.monthsSince = 0,
    this.openCaseId,
    this.openCaseOwner = '',
    this.lastOutcome = '',
    this.lastOutcomeAt,
  });

  bool get hasOpenCase => openCaseId != null;

  factory ReEngagementClient.fromJson(Map<String, dynamic> j) {
    final open = j['openCase'] is Map ? _map(j['openCase']) : null;
    final last = j['lastCase'] is Map ? _map(j['lastCase']) : null;
    return ReEngagementClient(
      customerName: _s(j['customerName']),
      phone: _s(j['phone']),
      phoneKey: _s(j['phoneKey']),
      service: _s(j['service']),
      lastEventDate: _d(j['lastEventDate']),
      lastBookingId: _id(j['lastBookingId']),
      bookings: _i(j['bookings']),
      monthsSince: _i(j['monthsSince']),
      openCaseId: open == null ? null : _s(open['id']),
      openCaseOwner: open == null ? '' : _s(open['ownerName']),
      lastOutcome: last == null ? '' : _s(last['outcome']),
      lastOutcomeAt: last == null ? null : _d(last['at']),
    );
  }

  Map<String, dynamic> toRequest() => {'phone': phone, 'customerName': customerName, if (lastBookingId != null) 'lastBookingId': lastBookingId};
}

/// What an assign call did: how many were assigned, and why the rest were not.
class CrmAssignResult {
  final int assigned;
  final List<String> skippedReasons;
  const CrmAssignResult({this.assigned = 0, this.skippedReasons = const []});
  factory CrmAssignResult.fromJson(Map<String, dynamic> j) =>
      CrmAssignResult(assigned: _i(j['assigned']), skippedReasons: _list(j['skipped']).map((s) => _s(s['reason'])).toList());
}
