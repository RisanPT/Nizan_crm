/// A planned piece of marketing content — one card on the content calendar.
/// Mirrors backend models/ContentItem.js.
class ContentItem {
  final String id;
  final String title;
  final String description;
  final String platform; // instagram | youtube | facebook | whatsapp | website | other
  final String contentType; // reel | post | story | carousel | video | blog | other
  final String status; // idea | planned | in-progress | scheduled | published | cancelled
  final DateTime scheduledDate;
  final DateTime? publishedDate;
  final String assignedToId;
  final String assignedToName;
  final String campaign;
  final String caption;
  final List<String> hashtags;
  final List<String> mediaUrls;
  final String notes;

  const ContentItem({
    required this.id,
    required this.title,
    required this.scheduledDate,
    this.description = '',
    this.platform = 'instagram',
    this.contentType = 'reel',
    this.status = 'idea',
    this.publishedDate,
    this.assignedToId = '',
    this.assignedToName = '',
    this.campaign = '',
    this.caption = '',
    this.hashtags = const [],
    this.mediaUrls = const [],
    this.notes = '',
  });

  factory ContentItem.fromJson(Map<String, dynamic> j) {
    final assignee = j['assignedTo'];
    return ContentItem(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      platform: (j['platform'] ?? 'instagram').toString(),
      contentType: (j['contentType'] ?? 'reel').toString(),
      status: (j['status'] ?? 'idea').toString(),
      scheduledDate: DateTime.tryParse((j['scheduledDate'] ?? '').toString())?.toLocal() ?? DateTime.now(),
      publishedDate: _date(j['publishedDate']),
      assignedToId: assignee is Map ? (assignee['_id'] ?? '').toString() : (assignee ?? '').toString(),
      assignedToName: assignee is Map ? (assignee['name'] ?? j['assignedToName'] ?? '').toString() : (j['assignedToName'] ?? '').toString(),
      campaign: (j['campaign'] ?? '').toString(),
      caption: (j['caption'] ?? '').toString(),
      hashtags: (j['hashtags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      mediaUrls: (j['mediaUrls'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      notes: (j['notes'] ?? '').toString(),
    );
  }

  static DateTime? _date(dynamic v) =>
      (v == null || v == '') ? null : DateTime.tryParse(v.toString())?.toLocal();
}

const contentStatuses = ['idea', 'planned', 'in-progress', 'scheduled', 'published', 'cancelled'];
const contentPlatforms = ['instagram', 'youtube', 'facebook', 'whatsapp', 'website', 'other'];
const contentTypes = ['reel', 'post', 'story', 'carousel', 'video', 'blog', 'other'];

String contentStatusLabel(String s) => switch (s) {
      'in-progress' => 'In Progress',
      'planned' => 'Planned',
      'scheduled' => 'Scheduled',
      'published' => 'Published',
      'cancelled' => 'Cancelled',
      _ => 'Idea',
    };

String contentTypeLabel(String t) => t.isEmpty ? '' : t[0].toUpperCase() + t.substring(1);
String platformLabel(String p) => switch (p) {
      'instagram' => 'Instagram',
      'youtube' => 'YouTube',
      'facebook' => 'Facebook',
      'whatsapp' => 'WhatsApp',
      'website' => 'Website',
      _ => 'Other',
    };

/// Dashboard counters returned by GET /content/stats.
class ContentStats {
  final int total;
  final Map<String, int> byStatus;
  final Map<String, int> byPlatform;
  final int scheduledThisMonth;
  final int publishedThisMonth;
  final int dueThisWeek;
  final int overdue;

  const ContentStats({
    this.total = 0,
    this.byStatus = const {},
    this.byPlatform = const {},
    this.scheduledThisMonth = 0,
    this.publishedThisMonth = 0,
    this.dueThisWeek = 0,
    this.overdue = 0,
  });

  factory ContentStats.fromJson(Map<String, dynamic> j) => ContentStats(
        total: (j['total'] as num?)?.toInt() ?? 0,
        byStatus: _intMap(j['byStatus']),
        byPlatform: _intMap(j['byPlatform']),
        scheduledThisMonth: (j['scheduledThisMonth'] as num?)?.toInt() ?? 0,
        publishedThisMonth: (j['publishedThisMonth'] as num?)?.toInt() ?? 0,
        dueThisWeek: (j['dueThisWeek'] as num?)?.toInt() ?? 0,
        overdue: (j['overdue'] as num?)?.toInt() ?? 0,
      );

  static Map<String, int> _intMap(dynamic v) {
    if (v is! Map) return const {};
    return v.map((k, val) => MapEntry(k.toString(), (val as num?)?.toInt() ?? 0));
  }
}
