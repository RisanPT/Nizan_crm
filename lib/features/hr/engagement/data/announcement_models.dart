// Announcement model — mirrors backend/models/Announcement.js.

const kAnnouncementCategories = <String>['announcement', 'event', 'celebration', 'policy'];

String announcementCategoryLabel(String c) => c.isEmpty ? 'Announcement' : c[0].toUpperCase() + c.substring(1);

DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

class Announcement {
  final String id;
  final String title;
  final String body;
  final String category;
  final DateTime? eventDate;
  final String audience;
  final bool pinned;
  final String postedByName;
  final DateTime? createdAt;

  const Announcement({
    required this.id,
    this.title = '',
    this.body = '',
    this.category = 'announcement',
    this.eventDate,
    this.audience = 'all',
    this.pinned = false,
    this.postedByName = '',
    this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        category: j['category'] as String? ?? 'announcement',
        eventDate: _date(j['eventDate']),
        audience: j['audience'] as String? ?? 'all',
        pinned: j['pinned'] as bool? ?? false,
        postedByName: j['postedByName'] as String? ?? '',
        createdAt: _date(j['createdAt']),
      );
}
