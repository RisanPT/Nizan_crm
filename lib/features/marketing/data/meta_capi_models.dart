// Lead results back to Meta (backend /api/meta/capi, the Conversions API): each stage a Lead Ads lead reaches in the CRM is told to Meta
// once, so Meta learns which leads book. The token stays on the server; the app sees whether each setting is set.

DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
String _s(Object? v) => v == null ? '' : v.toString();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
Map<String, dynamic> _m(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

/// The stages Meta gets, in funnel order (the server's CAPI_STAGES).
const kCapiStages = ['Lead', 'Contacted', 'Qualified', 'Follow-up', 'Converted', 'Lost'];

class MetaCapiRun {
  const MetaCapiRun({this.at, this.trigger = '', this.ok = false, this.problemCode = '', this.problem = '', this.planned = 0, this.sent = 0, this.failed = 0, this.skipped = 0, this.expired = 0});
  final DateTime? at;
  final String trigger, problemCode, problem;
  final bool ok;
  final int planned, sent, failed, skipped, expired;
  factory MetaCapiRun.fromJson(Map<String, dynamic> j) => MetaCapiRun(
    at: _d(j['at']),
    trigger: _s(j['trigger']),
    ok: j['ok'] == true,
    problemCode: _s(j['problemCode']),
    problem: _s(j['problem']),
    planned: _i(j['planned']),
    sent: _i(j['sent']),
    failed: _i(j['failed']),
    skipped: _i(j['skipped']),
    expired: _i(j['expired']),
  );

  /// "Sent 10 · 1 too old to send" — or why it failed.
  String get summary {
    if (!ok && problem.isNotEmpty) return problem;
    final parts = <String>[
      if (sent > 0) 'Sent $sent' else 'Nothing new to send',
      if (failed > 0) '$failed not taken',
      if (skipped > 0) '$skipped too old to send',
      if (expired > 0) '$expired grew too old',
    ];
    return parts.join(' · ');
  }
}

class MetaCapiEventRow {
  const MetaCapiEventRow({required this.id, this.leadgenId = '', this.leadId, this.leadName = '', this.stage = '', this.eventAt, this.status = 'pending', this.attempts = 0, this.retry = false, this.nextTryAt, this.problem = '', this.sentAt, this.test = false});
  final String id, leadgenId, leadName, stage, status, problem;
  final String? leadId;
  final DateTime? eventAt, nextTryAt, sentAt;
  final int attempts;
  final bool retry, test;
  factory MetaCapiEventRow.fromJson(Map<String, dynamic> j) => MetaCapiEventRow(
    id: _s(j['id']),
    leadgenId: _s(j['leadgenId']),
    leadId: j['leadId'] == null ? null : _s(j['leadId']),
    leadName: _s(j['leadName']),
    stage: _s(j['stage']),
    eventAt: _d(j['eventAt']),
    status: _s(j['status']),
    attempts: _i(j['attempts']),
    retry: j['retry'] == true,
    nextTryAt: _d(j['nextTryAt']),
    problem: _s(j['problem']),
    sentAt: _d(j['sentAt']),
    test: j['test'] == true,
  );

  String get statusLabel => switch (status) {
    'sent' => test ? 'Sent (test)' : 'Sent',
    'failed' => retry ? 'Will try again' : 'Not taken',
    'skipped' => 'Too old to send',
    'expired' => 'Grew too old',
    _ => 'Waiting',
  };
}

class MetaCapiStatus {
  const MetaCapiStatus({
    this.dataset = false,
    this.token = false,
    this.ownToken = false,
    this.testMode = false,
    this.ready = false,
    this.enabled = false,
    this.enabledAt,
    this.updatedByName = '',
    this.everyMinutes = 60,
    this.maxAgeDays = 7,
    this.windowDays = 35,
    this.crmName = 'Team N CRM',
    this.canManage = false,
    this.running = false,
    this.lastRun,
    this.lastSentAt,
    this.counts = const {},
    this.sentByStage = const {},
    this.followed = 0,
    this.recent = const [],
  });
  final bool dataset, token, ownToken, testMode, ready, enabled, canManage, running;
  final DateTime? enabledAt, lastSentAt;
  final String updatedByName, crmName;
  final int everyMinutes, maxAgeDays, windowDays, followed;
  final MetaCapiRun? lastRun;
  final Map<String, int> counts, sentByStage;
  final List<MetaCapiEventRow> recent;

  factory MetaCapiStatus.fromJson(Map<String, dynamic> j) {
    final c = _m(j['config']);
    final s = _m(j['settings']);
    Map<String, int> ints(Object? v) => _m(v).map((k, x) => MapEntry(k, _i(x)));
    return MetaCapiStatus(
      dataset: c['dataset'] == true,
      token: c['token'] == true,
      ownToken: c['ownToken'] == true,
      testMode: c['testMode'] == true,
      ready: c['ready'] == true,
      enabled: s['enabled'] == true,
      enabledAt: _d(s['enabledAt']),
      updatedByName: _s(s['updatedByName']),
      everyMinutes: _i(s['everyMinutes']) == 0 ? 60 : _i(s['everyMinutes']),
      maxAgeDays: _i(s['maxAgeDays']) == 0 ? 7 : _i(s['maxAgeDays']),
      windowDays: _i(s['windowDays']) == 0 ? 35 : _i(s['windowDays']),
      crmName: _s(s['crmName']).isEmpty ? 'Team N CRM' : _s(s['crmName']),
      canManage: j['canManage'] == true,
      running: j['running'] == true,
      lastRun: j['lastRun'] is Map ? MetaCapiRun.fromJson(_m(j['lastRun'])) : null,
      lastSentAt: _d(j['lastSentAt']),
      counts: ints(j['counts30']),
      sentByStage: ints(j['sentByStage30']),
      followed: _i(j['followed']),
      recent: (j['recent'] as List? ?? const []).whereType<Map>().map((e) => MetaCapiEventRow.fromJson(e.cast<String, dynamic>())).toList(),
    );
  }
}
