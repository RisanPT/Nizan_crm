// ── Trial Model ──────────────────────────────────────────────────────────────
// A Trial is a studio appointment where a bride tries one or more looks/packages.
// Trial packages are completely independent of the services Package catalog.

// ── TrialItem ────────────────────────────────────────────────────────────────
class TrialItem {
  final String packageName; // free-text e.g. "Bridal Classic"
  final String lookLabel;   // free-text e.g. "Bridal Look"
  final String notes;       // "Liked the base, adjust eye liner"
  final String outcome;     // pending | approved | needs_revision | rejected
  final double price;       // price for this package/look

  const TrialItem({
    this.packageName = '',
    this.lookLabel = '',
    this.notes = '',
    this.outcome = 'pending',
    this.price = 0.0,
  });

  factory TrialItem.fromJson(Map<String, dynamic> json) => TrialItem(
        packageName: json['packageName'] as String? ?? '',
        lookLabel: json['lookLabel'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        outcome: json['outcome'] as String? ?? 'pending',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'lookLabel': lookLabel,
        'notes': notes,
        'outcome': outcome,
        'price': price,
      };

  TrialItem copyWith({
    String? packageName,
    String? lookLabel,
    String? notes,
    String? outcome,
    double? price,
  }) =>
      TrialItem(
        packageName: packageName ?? this.packageName,
        lookLabel: lookLabel ?? this.lookLabel,
        notes: notes ?? this.notes,
        outcome: outcome ?? this.outcome,
        price: price ?? this.price,
      );
}

// ── Trial ────────────────────────────────────────────────────────────────────
class Trial {
  final String id;
  final String trialNumber;
  final String clientName;
  final String phone;
  final String email;
  final DateTime trialDate;
  final String startTime;
  final String endTime;
  final String status; // scheduled | completed | postponed | cancelled
  final String notes;
  final List<TrialItem> trialItems;
  final String bookingId;
  final DateTime? createdAt;

  const Trial({
    this.id = '',
    this.trialNumber = '',
    required this.clientName,
    required this.phone,
    this.email = '',
    required this.trialDate,
    this.startTime = '',
    this.endTime = '',
    this.status = 'scheduled',
    this.notes = '',
    this.trialItems = const [],
    this.bookingId = '',
    this.createdAt,
  });

  // ── fromJson ───────────────────────────────────────────────────────────────
  factory Trial.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      final raw = json['trialDate'] as String? ?? '';
      if (raw.length >= 10) {
        final parts = raw.substring(0, 10).split('-');
        parsedDate = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      } else {
        parsedDate = DateTime.now();
      }
    } catch (_) {
      parsedDate = DateTime.now();
    }

    DateTime? parsedCreated;
    try {
      final raw = json['createdAt'];
      if (raw != null) parsedCreated = DateTime.parse(raw as String);
    } catch (_) {}

    return Trial(
      id: json['_id'] as String? ?? '',
      trialNumber: json['trialNumber'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      trialDate: parsedDate,
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      status: json['status'] as String? ?? 'scheduled',
      notes: json['notes'] as String? ?? '',
      trialItems: ((json['trialItems'] as List?) ?? [])
          .map((e) => TrialItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      bookingId: (json['bookingId'] as String?) ?? '',
      createdAt: parsedCreated,
    );
  }

  // ── toJson ─────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    final y = trialDate.year.toString().padLeft(4, '0');
    final m = trialDate.month.toString().padLeft(2, '0');
    final d = trialDate.day.toString().padLeft(2, '0');
    return {
      'clientName': clientName,
      'phone': phone,
      'email': email,
      'trialDate': '$y-$m-$d',
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'notes': notes,
      'trialItems': trialItems.map((i) => i.toJson()).toList(),
      if (bookingId.isNotEmpty) 'bookingId': bookingId,
    };
  }

  // ── copyWith ───────────────────────────────────────────────────────────────
  Trial copyWith({
    String? id,
    String? trialNumber,
    String? clientName,
    String? phone,
    String? email,
    DateTime? trialDate,
    String? startTime,
    String? endTime,
    String? status,
    String? notes,
    List<TrialItem>? trialItems,
    String? bookingId,
    DateTime? createdAt,
  }) =>
      Trial(
        id: id ?? this.id,
        trialNumber: trialNumber ?? this.trialNumber,
        clientName: clientName ?? this.clientName,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        trialDate: trialDate ?? this.trialDate,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        trialItems: trialItems ?? this.trialItems,
        bookingId: bookingId ?? this.bookingId,
        createdAt: createdAt ?? this.createdAt,
      );
}
