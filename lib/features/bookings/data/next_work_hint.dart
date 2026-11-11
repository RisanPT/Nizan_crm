// An artist with several works in one day goes from one venue straight to the next.
// For each of their works the server says where it falls in their day ("work 2 of 3")
// and, when a later work follows, which one it is and how far it is from this one
// (GET /api/bookings/next-work).

double? _km(Object? v) => (v as num?)?.toDouble();

/// The work that follows, with the road from the one before it.
class NextWork {
  final String bookingId;
  final String bookingNumber;
  final String customerName;
  final String service;
  final DateTime? serviceStart;
  final DateTime? serviceEnd;

  /// A few words on where it is (the address, or the pincode).
  final String place;

  /// What staff saved in the booking's map field ('' when there is none).
  final String mapUrl;

  /// Road distance from the previous work; null when it could not be measured.
  final double? km;
  final int durationMin;

  /// A venue is only known to its pincode area, so the distance is a rough one.
  final bool approximate;

  const NextWork({
    required this.bookingId,
    required this.bookingNumber,
    required this.customerName,
    required this.service,
    required this.serviceStart,
    required this.serviceEnd,
    required this.place,
    required this.mapUrl,
    required this.km,
    required this.durationMin,
    required this.approximate,
  });

  factory NextWork.fromJson(Map<String, dynamic> j) => NextWork(
        bookingId: '${j['bookingId'] ?? ''}',
        bookingNumber: '${j['bookingNumber'] ?? ''}',
        customerName: '${j['customerName'] ?? ''}',
        service: '${j['service'] ?? ''}',
        serviceStart: DateTime.tryParse('${j['serviceStart'] ?? ''}')?.toLocal(),
        serviceEnd: DateTime.tryParse('${j['serviceEnd'] ?? ''}')?.toLocal(),
        place: '${j['place'] ?? ''}',
        mapUrl: '${j['mapUrl'] ?? ''}',
        km: _km(j['km']),
        durationMin: (j['durationMin'] as num?)?.toInt() ?? 0,
        approximate: j['approximate'] == true,
      );
}

/// One work's place in the artist's day.
class NextWorkHint {
  final String dayKey;

  /// 1-based position among the artist's works that day, and how many there are.
  final int position;
  final int total;

  /// The next work that day; null for the last one.
  final NextWork? next;

  const NextWorkHint({required this.dayKey, required this.position, required this.total, required this.next});

  /// Only worth showing when the day has more than one work.
  bool get isMultiWorkDay => total > 1;
  bool get isLast => total > 1 && next == null;

  factory NextWorkHint.fromJson(Map<String, dynamic> j) => NextWorkHint(
        dayKey: '${j['dayKey'] ?? ''}',
        position: (j['position'] as num?)?.toInt() ?? 1,
        total: (j['total'] as num?)?.toInt() ?? 1,
        next: j['next'] is Map ? NextWork.fromJson((j['next'] as Map).cast<String, dynamic>()) : null,
      );
}

class NextWorkHints {
  /// False when the server has no distance service set up: the next work is still
  /// named, there is just no distance to show.
  final bool distanceReady;
  final Map<String, NextWorkHint> byBooking;

  const NextWorkHints({required this.distanceReady, required this.byBooking});
  static const empty = NextWorkHints(distanceReady: true, byBooking: {});

  factory NextWorkHints.fromJson(Map<String, dynamic> j) => NextWorkHints(
        distanceReady: j['distanceReady'] != false,
        byBooking: {
          for (final e in ((j['hints'] as Map?) ?? const {}).entries)
            '${e.key}': NextWorkHint.fromJson((e.value as Map).cast<String, dynamic>()),
        },
      );
}
