/// Data for the Booking Map (GET /api/bookings/map): bookings grouped by place
/// (pincode, or district when there is none) with a package (service-type)
/// split and map coordinates.
class BookingMapTypeStat {
  final int bookings;
  final double sales;
  const BookingMapTypeStat({this.bookings = 0, this.sales = 0});

  factory BookingMapTypeStat.fromJson(Map<String, dynamic> j) =>
      BookingMapTypeStat(
        bookings: (j['bookings'] as num?)?.toInt() ?? 0,
        sales: (j['sales'] as num?)?.toDouble() ?? 0,
      );
}

class BookingMapPlace {
  final String key;
  final String pincode;
  final String label; // OSM place name, e.g. "Feroke"
  final String district;
  final double lat;
  final double lng;

  /// True while the pincode hasn't been located yet (or has none): the bubble
  /// sits at the district centre.
  final bool approximate;
  final int bookings;
  final double sales;
  final Map<String, BookingMapTypeStat> types;

  const BookingMapPlace({
    required this.key,
    required this.pincode,
    required this.label,
    required this.district,
    required this.lat,
    required this.lng,
    required this.approximate,
    required this.bookings,
    required this.sales,
    required this.types,
  });

  /// Display name: "Feroke · 673631", "673014", or the district.
  String get name {
    final place = label.trim();
    if (pincode.isNotEmpty) return place.isEmpty ? pincode : '$place · $pincode';
    return district.isEmpty ? 'Unknown' : _title(district);
  }

  String get subtitle {
    final d = _title(district);
    if (pincode.isEmpty) return 'District (no pincode)';
    return approximate ? '$d · locating…' : d;
  }

  BookingMapTypeStat statFor(String? type) => type == null
      ? BookingMapTypeStat(bookings: bookings, sales: sales)
      : (types[type] ?? const BookingMapTypeStat());

  factory BookingMapPlace.fromJson(Map<String, dynamic> j) => BookingMapPlace(
        key: j['key'] as String? ?? '',
        pincode: j['pincode'] as String? ?? '',
        label: j['label'] as String? ?? '',
        district: j['district'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
        approximate: j['approximate'] as bool? ?? false,
        bookings: (j['bookings'] as num?)?.toInt() ?? 0,
        sales: (j['sales'] as num?)?.toDouble() ?? 0,
        types: {
          for (final e in ((j['types'] as Map?) ?? const {}).entries)
            e.key.toString(): BookingMapTypeStat.fromJson(
                (e.value as Map).cast<String, dynamic>()),
        },
      );

  static String _title(String s) => s
      .trim()
      .toLowerCase()
      .replaceAllMapped(RegExp(r'\b([a-z])'), (m) => m[1]!.toUpperCase());
}

class BookingMapType {
  final String name;
  final int bookings;
  final double sales;
  final List<String> topServices;
  const BookingMapType({
    required this.name,
    required this.bookings,
    required this.sales,
    required this.topServices,
  });

  factory BookingMapType.fromJson(Map<String, dynamic> j) => BookingMapType(
        name: j['name'] as String? ?? '',
        bookings: (j['bookings'] as num?)?.toInt() ?? 0,
        sales: (j['sales'] as num?)?.toDouble() ?? 0,
        topServices: [
          for (final s in (j['topServices'] as List? ?? const []))
            '${(s as Map)['name']} (${s['bookings']})',
        ],
      );
}

class BookingMapData {
  final String basis; // 'event' | 'added'
  final int totalBookings;
  final double totalSales;
  final List<BookingMapPlace> places;
  final List<BookingMapType> types;
  final int unmappedBookings;
  final double unmappedSales;
  final int pendingGeocodes;

  const BookingMapData({
    required this.basis,
    required this.totalBookings,
    required this.totalSales,
    required this.places,
    required this.types,
    required this.unmappedBookings,
    required this.unmappedSales,
    required this.pendingGeocodes,
  });

  factory BookingMapData.fromJson(Map<String, dynamic> j) {
    final totals = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final unmapped = (j['unmapped'] as Map?)?.cast<String, dynamic>() ?? const {};
    return BookingMapData(
      basis: j['basis'] as String? ?? 'event',
      totalBookings: (totals['bookings'] as num?)?.toInt() ?? 0,
      totalSales: (totals['sales'] as num?)?.toDouble() ?? 0,
      places: [
        for (final p in (j['places'] as List? ?? const []))
          BookingMapPlace.fromJson((p as Map).cast<String, dynamic>()),
      ],
      types: [
        for (final t in (j['types'] as List? ?? const []))
          BookingMapType.fromJson((t as Map).cast<String, dynamic>()),
      ],
      unmappedBookings: (unmapped['bookings'] as num?)?.toInt() ?? 0,
      unmappedSales: (unmapped['sales'] as num?)?.toDouble() ?? 0,
      pendingGeocodes: (j['pendingGeocodes'] as num?)?.toInt() ?? 0,
    );
  }
}
