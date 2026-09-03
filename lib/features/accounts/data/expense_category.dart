class ExpenseCategory {
  final String id;
  final String name;
  final String department;
  final bool active;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.department,
    this.active = true,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) => ExpenseCategory(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        name: json['name'] as String? ?? '',
        department: json['department'] as String? ?? '',
        active: json['active'] as bool? ?? true,
      );

  /// Human-readable label. Legacy seed values are stored as snake_case slugs
  /// (e.g. `office_supplies`); custom categories are stored as typed. This
  /// prettifies both (it's a no-op for already-readable names).
  String get label => prettyCategory(name);
}

/// Turns a stored category value into a display label. Idempotent for names
/// that are already readable ("Team Lunch" → "Team Lunch"; "office_supplies" →
/// "Office Supplies").
String prettyCategory(String value) {
  final v = value.trim();
  if (v.isEmpty) return '';
  return v
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
