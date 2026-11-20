// Meta Lead Ads (backend /api/meta): forms filled on Facebook / Instagram ads become CRM leads on their own. The secrets live on the
// server; the app only ever sees whether each one is set.

DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
String _s(Object? v) => v == null ? '' : v.toString();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
Map<String, dynamic> _m(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};
List<Map<String, dynamic>> _l(Object? v) => v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];

/// What the server has: each setting yes / no (never its value), the Graph version, the webhook's path.
class MetaConfig {
  const MetaConfig({this.appSecret = false, this.token = false, this.verifyToken = false, this.ready = false, this.version = '', this.webhookPath = '/api/meta/webhook'});
  final bool appSecret, token, verifyToken, ready;
  final String version, webhookPath;
  factory MetaConfig.fromJson(Map<String, dynamic> j) => MetaConfig(
    appSecret: j['appSecret'] == true,
    token: j['token'] == true,
    verifyToken: j['verifyToken'] == true,
    ready: j['ready'] == true,
    version: _s(j['version']),
    webhookPath: _s(j['webhookPath']).isEmpty ? '/api/meta/webhook' : _s(j['webhookPath']),
  );
}

class MetaPerson {
  const MetaPerson({required this.id, required this.name, this.role = '', this.active = true});
  final String id, name, role;
  final bool active;
  factory MetaPerson.fromJson(Map<String, dynamic> j) => MetaPerson(id: _s(j['id']), name: _s(j['name']), role: _s(j['role']), active: j['active'] != false);
}

/// The last "Check for missed leads".
class MetaCheckResult {
  const MetaCheckResult({this.at, this.byName = '', this.days = 0, this.forms = 0, this.found = 0, this.added = 0, this.already = 0, this.failed = 0, this.problem = ''});
  final DateTime? at;
  final String byName, problem;
  final int days, forms, found, added, already, failed;
  factory MetaCheckResult.fromJson(Map<String, dynamic> j) => MetaCheckResult(
    at: _d(j['at']),
    byName: _s(j['byName']),
    days: _i(j['days']),
    forms: _i(j['forms']),
    found: _i(j['found']),
    added: _i(j['added']),
    already: _i(j['already']),
    failed: _i(j['failed']),
    problem: _s(j['problem']),
  );

  /// "Found 12 leads in 3 forms: 2 new, now in the CRM; 10 were already here."
  String get summary {
    if (forms == 0 && problem.isNotEmpty) return problem;
    final parts = <String>[
      if (added > 0) '$added taken in now',
      if (already > 0) '$already already here',
      if (failed > 0) '$failed could not be taken in',
    ];
    final head = 'Found $found lead${found == 1 ? '' : 's'} in $forms form${forms == 1 ? '' : 's'} (last $days day${days == 1 ? '' : 's'})';
    return parts.isEmpty ? head : '$head: ${parts.join(', ')}.';
  }
}

class MetaLeadsStatus {
  const MetaLeadsStatus({
    this.config = const MetaConfig(),
    this.canManage = false,
    this.assignMode = 'none',
    this.rotateUsers = const [],
    this.updatedByName = '',
    this.pageIds = const [],
    this.lastCheck,
    this.lastLeadAt,
    this.created = 0,
    this.existing = 0,
    this.failed = 0,
    this.waiting = 0,
    this.assignees = const [],
  });
  final MetaConfig config;
  final bool canManage;
  final String assignMode, updatedByName;
  final List<MetaPerson> rotateUsers, assignees;
  final List<String> pageIds;
  final MetaCheckResult? lastCheck;
  final DateTime? lastLeadAt;
  final int created, existing, failed, waiting;

  bool get rotates => assignMode == 'rotate' && rotateUsers.isNotEmpty;

  factory MetaLeadsStatus.fromJson(Map<String, dynamic> j) {
    final s = _m(j['settings']);
    final c = _m(j['counts30']);
    return MetaLeadsStatus(
      config: MetaConfig.fromJson(_m(j['config'])),
      canManage: j['canManage'] == true,
      assignMode: _s(s['assignMode']).isEmpty ? 'none' : _s(s['assignMode']),
      rotateUsers: _l(s['rotateUsers']).map(MetaPerson.fromJson).toList(),
      updatedByName: _s(s['updatedByName']),
      pageIds: (j['pageIds'] as List? ?? const []).map(_s).where((x) => x.isNotEmpty).toList(),
      lastCheck: j['lastCheck'] is Map ? MetaCheckResult.fromJson(_m(j['lastCheck'])) : null,
      lastLeadAt: _d(j['lastLeadAt']),
      created: _i(c['created']),
      existing: _i(c['existing']),
      failed: _i(c['failed']),
      waiting: _i(c['waiting']),
      assignees: _l(j['assignees']).map(MetaPerson.fromJson).toList(),
    );
  }
}

/// One lead Meta told us about, and what became of it.
class MetaLeadEvent {
  const MetaLeadEvent({
    required this.id,
    this.leadgenId = '',
    this.via = 'webhook',
    this.status = 'received',
    this.submittedAt,
    this.receivedAt,
    this.nextTryAt,
    this.attempts = 0,
    this.retry = false,
    this.problemCode = '',
    this.problemText = '',
    this.leadName = '',
    this.email = '',
    this.formName = '',
    this.adName = '',
    this.campaignName = '',
    this.platform = '',
    this.isOrganic = false,
    this.leadId,
    this.assignedToName = '',
  });
  final String id, leadgenId, via, status, problemCode, problemText, leadName, email, formName, adName, campaignName, platform, assignedToName;
  final DateTime? submittedAt, receivedAt, nextTryAt;
  final int attempts;
  final bool retry, isOrganic;
  final String? leadId;

  factory MetaLeadEvent.fromJson(Map<String, dynamic> j) => MetaLeadEvent(
    id: _s(j['id']),
    leadgenId: _s(j['leadgenId']),
    via: _s(j['via']),
    status: _s(j['status']),
    submittedAt: _d(j['submittedAt']),
    receivedAt: _d(j['receivedAt']),
    nextTryAt: _d(j['nextTryAt']),
    attempts: _i(j['attempts']),
    retry: j['retry'] == true,
    problemCode: _s(j['problemCode']),
    problemText: _s(j['problemText']),
    leadName: _s(j['leadName']),
    email: _s(j['email']),
    formName: _s(j['formName']),
    adName: _s(j['adName']),
    campaignName: _s(j['campaignName']),
    platform: _s(j['platform']),
    isOrganic: j['isOrganic'] == true,
    leadId: j['leadId'] == null ? null : _s(j['leadId']),
    assignedToName: _s(j['assignedToName']),
  );

  bool get failed => status == 'failed';
  bool get waiting => status == 'received' || status == 'working';

  /// The status as the team reads it.
  String get statusLabel => switch (status) {
    'created' => 'New lead',
    'existing' => 'Already a lead',
    'failed' => 'Not taken in',
    _ => 'Waiting',
  };

  /// "Instagram · form "Bridal Nov" · ad "Reel 17""
  String get origin {
    final where = platform == 'ig' ? 'Instagram' : (platform == 'fb' ? 'Facebook' : 'Meta');
    return [
      isOrganic ? '$where (no ad)' : where,
      if (formName.isNotEmpty) 'form "$formName"',
      if (adName.isNotEmpty) 'ad "$adName"',
      if (campaignName.isNotEmpty) 'campaign "$campaignName"',
    ].join(' · ');
  }
}

class MetaEventPage {
  const MetaEventPage({this.items = const [], this.total = 0, this.page = 1, this.pages = 1});
  final List<MetaLeadEvent> items;
  final int total, page, pages;
  factory MetaEventPage.fromJson(Map<String, dynamic> j) => MetaEventPage(
    items: _l(j['items']).map(MetaLeadEvent.fromJson).toList(),
    total: _i(j['total']),
    page: _i(j['page']) == 0 ? 1 : _i(j['page']),
    pages: _i(j['pages']) == 0 ? 1 : _i(j['pages']),
  );
}

/// "Test connection": who the token is and whether each Page can be read.
class MetaTestResult {
  const MetaTestResult({this.ok = false, this.name = '', this.problem = '', this.pages = const []});
  final bool ok;
  final String name, problem;
  final List<({String id, String name, bool ok, String problem})> pages;
  factory MetaTestResult.fromJson(Map<String, dynamic> j) => MetaTestResult(
    ok: j['ok'] == true,
    name: _s(j['name']),
    problem: _s(_m(j['problem'])['text']),
    pages: _l(j['pages']).map((p) => (id: _s(p['id']), name: _s(p['name']), ok: p['ok'] == true, problem: _s(p['problem']))).toList(),
  );
}
