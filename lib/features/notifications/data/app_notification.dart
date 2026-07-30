/// A single in-app notification delivered to the signed-in user.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? leadId;
  final String? leadName;
  final String? bookingId;
  /// Generic in-app route this notification points at (e.g. '/fleet/assignments').
  final String link;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.leadId,
    this.leadName,
    this.bookingId,
    this.link = '',
    this.read = false,
    required this.createdAt,
  });

  static String? _id(dynamic v) {
    if (v == null) return null;
    if (v is Map) return v['_id'] as String?;
    return v as String?;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final lead = json['leadId'];
    return AppNotification(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      leadId: _id(lead),
      leadName: lead is Map ? lead['name'] as String? : null,
      bookingId: _id(json['bookingId']),
      link: json['link'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
    );
  }

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        leadId: leadId,
        leadName: leadName,
        bookingId: bookingId,
        link: link,
        read: read ?? this.read,
        createdAt: createdAt,
      );
}

/// A page of notifications plus the current unread total.
class NotificationPage {
  final List<AppNotification> items;
  final int unreadCount;
  final int totalPages;
  final int page;

  const NotificationPage({
    required this.items,
    required this.unreadCount,
    required this.totalPages,
    required this.page,
  });

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    return NotificationPage(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      page: (json['page'] as num?)?.toInt() ?? 1,
    );
  }
}
