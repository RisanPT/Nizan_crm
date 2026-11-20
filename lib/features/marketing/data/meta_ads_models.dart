import 'package:intl/intl.dart';

// The live Meta ad spend sync (backend /api/meta/ads): spend, reach, impressions, clicks, ads and audiences brought in from Meta on their
// own. The secrets stay on the server; the app sees whether each is set and the ad accounts' ids and brands.

DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
String _s(Object? v) => v == null ? '' : v.toString();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
double _n(Object? v) => (v as num?)?.toDouble() ?? 0;
Map<String, dynamic> _m(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};
List<Map<String, dynamic>> _l(Object? v) => v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];

/// ₹12,340 (whole rupees).
String metaInr(num v) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

/// "16 Nov" or "16 – 18 Nov" (a day pair from the server, YYYY-MM-DD).
String metaDays(String from, String to) {
  final a = DateTime.tryParse(from);
  final b = DateTime.tryParse(to);
  if (a == null) return to;
  if (b == null || from == to) return DateFormat('d MMM').format(a);
  if (a.month == b.month && a.year == b.year) return '${a.day} – ${DateFormat('d MMM').format(b)}';
  return '${DateFormat('d MMM').format(a)} – ${DateFormat('d MMM').format(b)}';
}

class MetaAdAccount {
  const MetaAdAccount({required this.id, this.brand = 'kerala'});
  final String id, brand;
  String get brandLabel => brand == 'main' ? 'Main' : 'Kerala';
  factory MetaAdAccount.fromJson(Map<String, dynamic> j) => MetaAdAccount(id: _s(j['id']), brand: _s(j['brand']).isEmpty ? 'kerala' : _s(j['brand']));
}

/// What one run did, or why it failed.
class MetaSyncRun {
  const MetaSyncRun({
    this.at,
    this.doneAt,
    this.trigger = '',
    this.byName = '',
    this.from = '',
    this.to = '',
    this.ok = false,
    this.problemCode = '',
    this.problem = '',
    this.campaigns = 0,
    this.campaignDays = 0,
    this.adDays = 0,
    this.segments = 0,
    this.adsCreated = 0,
    this.spend = 0,
    this.unlinkedSpend = 0,
  });
  final DateTime? at, doneAt;
  final String trigger, byName, from, to, problemCode, problem;
  final bool ok;
  final int campaigns, campaignDays, adDays, segments, adsCreated;
  final double spend, unlinkedSpend;

  factory MetaSyncRun.fromJson(Map<String, dynamic> j) => MetaSyncRun(
    at: _d(j['at']),
    doneAt: _d(j['doneAt']),
    trigger: _s(j['trigger']),
    byName: _s(j['byName']),
    from: _s(j['from']),
    to: _s(j['to']),
    ok: j['ok'] == true,
    problemCode: _s(j['problemCode']),
    problem: _s(j['problem']),
    campaigns: _i(j['campaigns']),
    campaignDays: _i(j['campaignDays']),
    adDays: _i(j['adDays']),
    segments: _i(j['segments']),
    adsCreated: _i(j['adsCreated']),
    spend: _n(j['spend']),
    unlinkedSpend: _n(j['unlinkedSpend']),
  );

  /// "₹12,340 on 5 campaigns, 16 – 18 Nov" — or the reason it failed.
  String get summary {
    if (!ok) return problem.isEmpty ? 'The sync failed.' : problem;
    final days = metaDays(from, to);
    if (campaigns == 0) return 'No spend on a linked campaign, $days.';
    return '${metaInr(spend)} on $campaigns campaign${campaigns == 1 ? '' : 's'}, $days.';
  }

  /// "60 campaign-days · 120 ad-days · 240 audience rows · 2 new ads"
  String get details => [
    '$campaignDays campaign-day${campaignDays == 1 ? '' : 's'}',
    '$adDays ad-day${adDays == 1 ? '' : 's'}',
    '$segments audience row${segments == 1 ? '' : 's'}',
    if (adsCreated > 0) '$adsCreated new ad${adsCreated == 1 ? '' : 's'}',
  ].join(' · ');

  String get how => switch (trigger) { 'auto' => 'automatic', 'link' => 'after linking', _ => byName.isEmpty ? 'by hand' : 'by $byName' };
}

/// A Meta campaign that spent money but matches no CRM campaign: its spend is not counted until it is linked or added.
class MetaUnlinked {
  const MetaUnlinked({required this.metaId, this.name = '', this.accountId = '', this.brand = 'kerala', this.reason = 'no_match', this.firstDay = '', this.lastDay = '', this.spend = 0, this.runFrom = '', this.runTo = ''});
  final String metaId, name, accountId, brand, reason, firstDay, lastDay, runFrom, runTo;
  final double spend;
  String get brandLabel => brand == 'main' ? 'Main' : 'Kerala';
  bool get ambiguous => reason == 'ambiguous';
  factory MetaUnlinked.fromJson(Map<String, dynamic> j) => MetaUnlinked(
    metaId: _s(j['metaId']),
    name: _s(j['name']),
    accountId: _s(j['accountId']),
    brand: _s(j['brand']).isEmpty ? 'kerala' : _s(j['brand']),
    reason: _s(j['reason']),
    firstDay: _s(j['firstDay']),
    lastDay: _s(j['lastDay']),
    spend: _n(j['spend']),
    runFrom: _s(j['runFrom']),
    runTo: _s(j['runTo']),
  );
}

class MetaCampaignChoice {
  const MetaCampaignChoice({required this.id, required this.title, this.brand = ''});
  final String id, title, brand;
  factory MetaCampaignChoice.fromJson(Map<String, dynamic> j) => MetaCampaignChoice(id: _s(j['id']), title: _s(j['title']), brand: _s(j['brand']));
}

class MetaSyncHistory {
  const MetaSyncHistory({required this.id, this.at, this.byName = '', this.from = '', this.to = '', this.written = 0});
  final String id, byName, from, to;
  final DateTime? at;
  final int written;
  factory MetaSyncHistory.fromJson(Map<String, dynamic> j) => MetaSyncHistory(id: _s(j['id']), at: _d(j['at']), byName: _s(j['byName']), from: _s(j['from']), to: _s(j['to']), written: _i(j['written']));
}

class MetaAdsStatus {
  const MetaAdsStatus({
    this.appSecret = false,
    this.token = false,
    this.accounts = const [],
    this.ready = false,
    this.version = '',
    this.autoSync = true,
    this.everyHours = 6,
    this.daysBack = 3,
    this.maxDays = 92,
    this.updatedByName = '',
    this.canManage = false,
    this.running = false,
    this.lastRun,
    this.lastOkAt,
    this.nextAutoAt,
    this.unlinked = const [],
    this.ignored = const [],
    this.choices = const [],
    this.history = const [],
  });
  final bool appSecret, token, ready, autoSync, canManage, running;
  final List<MetaAdAccount> accounts;
  final String version, updatedByName;
  final int everyHours, daysBack, maxDays;
  final MetaSyncRun? lastRun;
  final DateTime? lastOkAt, nextAutoAt;
  final List<MetaUnlinked> unlinked;
  final List<String> ignored;
  final List<MetaCampaignChoice> choices;
  final List<MetaSyncHistory> history;

  factory MetaAdsStatus.fromJson(Map<String, dynamic> j) {
    final c = _m(j['config']);
    final s = _m(j['settings']);
    return MetaAdsStatus(
      appSecret: c['appSecret'] == true,
      token: c['token'] == true,
      accounts: _l(c['accounts']).map(MetaAdAccount.fromJson).toList(),
      ready: c['ready'] == true,
      version: _s(c['version']),
      autoSync: s['autoSync'] != false,
      everyHours: _i(s['everyHours']) == 0 ? 6 : _i(s['everyHours']),
      daysBack: _i(s['daysBack']) == 0 ? 3 : _i(s['daysBack']),
      maxDays: _i(s['maxDays']) == 0 ? 92 : _i(s['maxDays']),
      updatedByName: _s(s['updatedByName']),
      canManage: j['canManage'] == true,
      running: j['running'] == true,
      lastRun: j['lastRun'] is Map ? MetaSyncRun.fromJson(_m(j['lastRun'])) : null,
      lastOkAt: _d(j['lastOkAt']),
      nextAutoAt: _d(j['nextAutoAt']),
      unlinked: _l(j['unlinked']).map(MetaUnlinked.fromJson).toList(),
      ignored: (j['ignored'] as List? ?? const []).map(_s).where((x) => x.isNotEmpty).toList(),
      choices: _l(j['campaignChoices']).map(MetaCampaignChoice.fromJson).toList(),
      history: _l(j['history']).map(MetaSyncHistory.fromJson).toList(),
    );
  }
}

/// What linking or adding did.
class MetaLinkResult {
  const MetaLinkResult({this.linked = 0, this.leadsTagged = 0, this.run, this.busy = false});
  final int linked, leadsTagged;
  final MetaSyncRun? run;
  final bool busy;
  factory MetaLinkResult.fromJson(Map<String, dynamic> j) {
    final r = _m(j['run']);
    return MetaLinkResult(
      linked: (j['linked'] as List? ?? const []).length,
      leadsTagged: _i(j['leadsTagged']),
      busy: r['busy'] == true,
      run: r.isEmpty || r['busy'] == true ? null : MetaSyncRun.fromJson(r),
    );
  }

  String get message {
    final parts = <String>[
      linked == 1 ? 'Linked' : '$linked campaigns linked',
      if (leadsTagged > 0) leadsTagged == 1 ? '1 Meta lead now carries the campaign' : '$leadsTagged Meta leads now carry the campaign',
      if (busy) '${linked == 1 ? 'its' : 'their'} figures come with the next sync'
      else if (run != null && !run!.ok) 'figures not brought in: ${run!.problem}'
      else if (run != null) 'figures brought in',
    ];
    return '${parts.join('; ')}.';
  }
}
