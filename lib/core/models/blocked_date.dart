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
          ? DateTime.parse(json['date'] as String).toLocal()
          : DateTime.now(),
      reason: json['reason'] as String? ?? '',
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'reason': reason,
      'active': active,
    };
  }
}
