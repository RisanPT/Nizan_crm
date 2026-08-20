/// A morning/evening half of a day's booking capacity.
class SlotHalf {
  final int capacity;
  final int booked;
  final int available;
  const SlotHalf({required this.capacity, required this.booked, required this.available});

  factory SlotHalf.fromJson(Map<String, dynamic> j) => SlotHalf(
        capacity: (j['capacity'] as num?)?.toInt() ?? 0,
        booked: (j['booked'] as num?)?.toInt() ?? 0,
        available: (j['available'] as num?)?.toInt() ?? 0,
      );

  bool get isFull => available <= 0;
}

/// One calendar day's capacity. `total` is the day gate (morning + evening);
/// morning/evening are kept for an informational breakdown.
class DaySlot {
  final DateTime date;
  final bool isOverride;
  final bool blocked;
  final SlotHalf morning;
  final SlotHalf evening;
  final SlotHalf total;
  const DaySlot({
    required this.date,
    required this.isOverride,
    required this.blocked,
    required this.morning,
    required this.evening,
    required this.total,
  });

  factory DaySlot.fromJson(Map<String, dynamic> j) {
    final morning = SlotHalf.fromJson((j['morning'] as Map).cast<String, dynamic>());
    final evening = SlotHalf.fromJson((j['evening'] as Map).cast<String, dynamic>());
    final totalJson = j['total'];
    final total = totalJson is Map
        ? SlotHalf.fromJson(totalJson.cast<String, dynamic>())
        : SlotHalf(
            capacity: morning.capacity + evening.capacity,
            booked: morning.booked + evening.booked,
            available: (morning.capacity + evening.capacity - morning.booked - evening.booked)
                .clamp(0, 1 << 31),
          );
    return DaySlot(
      date: DateTime.parse(j['date'] as String),
      isOverride: j['isOverride'] == true,
      blocked: j['blocked'] == true,
      morning: morning,
      evening: evening,
      total: total,
    );
  }

  int get available => blocked ? 0 : total.available;
  bool get fullyBooked => total.isFull;
  /// No bookings can be added — either HR-blocked or at total capacity.
  bool get unavailable => blocked || total.isFull;
}

/// A month's availability plus the company-wide defaults.
class MonthAvailability {
  final int year;
  final int month;
  final int defaultMorning;
  final int defaultEvening;
  final int totalCapacity;
  final int totalAvailable;
  final int totalBooked;
  final List<DaySlot> days;

  const MonthAvailability({
    required this.year,
    required this.month,
    required this.defaultMorning,
    required this.defaultEvening,
    required this.totalCapacity,
    required this.totalAvailable,
    required this.totalBooked,
    required this.days,
  });

  factory MonthAvailability.fromJson(Map<String, dynamic> j) {
    final defaults = (j['defaults'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MonthAvailability(
      year: (j['year'] as num?)?.toInt() ?? 0,
      month: (j['month'] as num?)?.toInt() ?? 0,
      defaultMorning: (defaults['morning'] as num?)?.toInt() ?? 0,
      defaultEvening: (defaults['evening'] as num?)?.toInt() ?? 0,
      totalCapacity: (j['totalCapacity'] as num?)?.toInt() ?? 0,
      totalAvailable: (j['totalAvailable'] as num?)?.toInt() ?? 0,
      totalBooked: (j['totalBooked'] as num?)?.toInt() ?? 0,
      days: ((j['days'] as List?) ?? const [])
          .map((e) => DaySlot.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Company-wide default capacity per half.
class SlotDefaults {
  final int morning;
  final int evening;
  const SlotDefaults({required this.morning, required this.evening});

  factory SlotDefaults.fromJson(Map<String, dynamic> j) => SlotDefaults(
        morning: (j['morning'] as num?)?.toInt() ?? 0,
        evening: (j['evening'] as num?)?.toInt() ?? 0,
      );
}
