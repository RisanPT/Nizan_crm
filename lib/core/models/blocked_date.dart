/// 'YYYY-MM-DD' of [d]'s calendar day — what the server stores for a blocked
/// day, with no time or timezone to shift it.
String dayString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The India (IST) calendar day of a stored blocked date. Older rows were
/// saved at the server's midnight (00:00Z on a UTC server, 18:30Z the day
/// before on an IST server); the IST day is right for both, and matches the
/// server's slot calendar (utils/slots.js dayKey).
DateTime blockedDayOf(String raw) {
  final ist = DateTime.parse(raw).toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime(ist.year, ist.month, ist.day);
}

class BlockedDate {
  final String id;
  final DateTime date;
  final String reason;
  final bool active;

  const BlockedDate({
    required this.id,
    required this.date,
    this.reason = '',
    this.active = true,
  });

  factory BlockedDate.fromJson(Map<String, dynamic> json) {
    return BlockedDate(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      date: json['date'] != null
          ? blockedDayOf(json['date'] as String)
          : DateTime.now(),
      reason: json['reason'] as String? ?? '',
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': dayString(date),
      'reason': reason,
      'active': active,
    };
  }
}
