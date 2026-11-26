// Instagram insights (backend /api/meta/ig): followers and each recent post's reach, views, likes, comments, shares and saves, brought
// into the Socials module. The token stays on the server; the app sees whether each setting is set and the accounts' ids and brands.

DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
String _s(Object? v) => v == null ? '' : v.toString();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
Map<String, dynamic> _m(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};
List<Map<String, dynamic>> _l(Object? v) => v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];

String _brand(String b) => b == 'kerala' ? 'Kerala' : 'Main';

class MetaIgAccount {
  const MetaIgAccount({required this.id, this.brand = 'main', this.username = '', this.followers, this.syncedAt});
  final String id, brand, username;
  final int? followers;
  final DateTime? syncedAt;
  String get brandLabel => _brand(brand);
  factory MetaIgAccount.fromJson(Map<String, dynamic> j) => MetaIgAccount(id: _s(j['id']), brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']), username: _s(j['username']), followers: (j['followers'] as num?)?.toInt(), syncedAt: _d(j['syncedAt']));
}

class MetaIgRun {
  const MetaIgRun({this.at, this.trigger = '', this.byName = '', this.days = 0, this.ok = false, this.problemCode = '', this.problem = '', this.accounts = 0, this.media = 0, this.updated = 0, this.linked = 0, this.unmatched = 0, this.gaps = 0});
  final DateTime? at;
  final String trigger, byName, problemCode, problem;
  final bool ok;
  final int days, accounts, media, updated, linked, unmatched, gaps;
  factory MetaIgRun.fromJson(Map<String, dynamic> j) => MetaIgRun(
    at: _d(j['at']),
    trigger: _s(j['trigger']),
    byName: _s(j['byName']),
    days: _i(j['days']),
    ok: j['ok'] == true,
    problemCode: _s(j['problemCode']),
    problem: _s(j['problem']),
    accounts: _i(j['accounts']),
    media: _i(j['media']),
    updated: _i(j['updated']),
    linked: _i(j['linked']),
    unmatched: _i(j['unmatched']),
    gaps: _i(j['gaps']),
  );

  /// "24 posts read: 20 posts updated (3 newly linked); 4 to add or link." — or why it failed.
  String get summary {
    if (!ok) return problem.isEmpty ? 'The sync failed.' : problem;
    final parts = <String>['$updated post${updated == 1 ? '' : 's'} updated${linked > 0 ? ' ($linked newly linked)' : ''}', if (unmatched > 0) '$unmatched to add or link'];
    return '$media post${media == 1 ? '' : 's'} read (last $days days): ${parts.join('; ')}.';
  }

  String get how => switch (trigger) { 'auto' => 'automatic', _ => byName.isEmpty ? 'by hand' : 'by $byName' };
}

/// An Instagram post no Socials post matched.
class MetaIgUnmatched {
  const MetaIgUnmatched({required this.mediaId, this.username = '', this.brand = 'main', this.contentType = 'post', this.caption = '', this.permalink = '', this.at, this.metrics = const {}});
  final String mediaId, username, brand, contentType, caption, permalink;
  final DateTime? at;
  final Map<String, int> metrics;
  String get brandLabel => _brand(brand);
  String get firstLine => caption.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => '');
  factory MetaIgUnmatched.fromJson(Map<String, dynamic> j) => MetaIgUnmatched(
    mediaId: _s(j['mediaId']),
    username: _s(j['username']),
    brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
    contentType: _s(j['contentType']),
    caption: _s(j['caption']),
    permalink: _s(j['permalink']),
    at: _d(j['at']),
    metrics: _m(j['metrics']).map((k, v) => MapEntry(k, _i(v))),
  );
}

class MetaIgPostChoice {
  const MetaIgPostChoice({required this.id, required this.title, this.brand = 'main', this.contentType = '', this.status = '', this.scheduledDate});
  final String id, title, brand, contentType, status;
  final DateTime? scheduledDate;
  factory MetaIgPostChoice.fromJson(Map<String, dynamic> j) => MetaIgPostChoice(id: _s(j['id']), title: _s(j['title']), brand: _s(j['brand']), contentType: _s(j['contentType']), status: _s(j['status']), scheduledDate: _d(j['scheduledDate']));
}

/// "Find my Instagram accounts": each Facebook Page's Instagram business account.
class MetaIgFound {
  const MetaIgFound({required this.pageId, this.pageName = '', this.igId = '', this.username = '', this.followers = 0, this.problem = ''});
  final String pageId, pageName, igId, username, problem;
  final int followers;
  factory MetaIgFound.fromJson(Map<String, dynamic> j) => MetaIgFound(pageId: _s(j['pageId']), pageName: _s(j['pageName']), igId: _s(j['igId']), username: _s(j['username']), followers: _i(j['followers']), problem: _s(j['problem']));
}

class MetaIgStatus {
  const MetaIgStatus({
    this.appSecret = false,
    this.token = false,
    this.accounts = const [],
    this.ready = false,
    this.canFind = false,
    this.autoSync = true,
    this.everyHours = 6,
    this.days = 30,
    this.maxDays = 90,
    this.canManage = false,
    this.running = false,
    this.lastRun,
    this.lastOkAt,
    this.nextAutoAt,
    this.syncedPosts = 0,
    this.unmatched = const [],
    this.ignored = const [],
    this.choices = const [],
  });
  final bool appSecret, token, ready, canFind, autoSync, canManage, running;
  final List<MetaIgAccount> accounts;
  final int everyHours, days, maxDays, syncedPosts;
  final MetaIgRun? lastRun;
  final DateTime? lastOkAt, nextAutoAt;
  final List<MetaIgUnmatched> unmatched;
  final List<String> ignored;
  final List<MetaIgPostChoice> choices;

  factory MetaIgStatus.fromJson(Map<String, dynamic> j) {
    final c = _m(j['config']);
    final s = _m(j['settings']);
    return MetaIgStatus(
      appSecret: c['appSecret'] == true,
      token: c['token'] == true,
      accounts: _l(c['accounts']).map(MetaIgAccount.fromJson).toList(),
      ready: c['ready'] == true,
      canFind: c['canFind'] == true,
      autoSync: s['autoSync'] != false,
      everyHours: _i(s['everyHours']) == 0 ? 6 : _i(s['everyHours']),
      days: _i(s['days']) == 0 ? 30 : _i(s['days']),
      maxDays: _i(s['maxDays']) == 0 ? 90 : _i(s['maxDays']),
      canManage: j['canManage'] == true,
      running: j['running'] == true,
      lastRun: j['lastRun'] is Map ? MetaIgRun.fromJson(_m(j['lastRun'])) : null,
      lastOkAt: _d(j['lastOkAt']),
      nextAutoAt: _d(j['nextAutoAt']),
      syncedPosts: _i(j['syncedPosts']),
      unmatched: _l(j['unmatched']).map(MetaIgUnmatched.fromJson).toList(),
      ignored: (j['ignored'] as List? ?? const []).map(_s).where((x) => x.isNotEmpty).toList(),
      choices: _l(j['postChoices']).map(MetaIgPostChoice.fromJson).toList(),
    );
  }
}
