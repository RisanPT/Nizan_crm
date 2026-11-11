/// One level of the geography (district, region, state or zone).
class PlaceRef {
  final String id;
  final String name;
  const PlaceRef({required this.id, required this.name});

  static PlaceRef? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = '${json['id'] ?? json['_id'] ?? ''}';
    final name = '${json['name'] ?? ''}';
    return id.isEmpty && name.isEmpty ? null : PlaceRef(id: id, name: name);
  }
}

/// Where a pincode is, as GET /api/pincodes/lookup/:code answers.
///
/// [source]: `master` = it is in our pincode list; `geocode` = it is not, but the map files it under a
/// district we have (a suggestion, not fact); `none` = nothing known beyond maybe the [area].
class PincodeLookup {
  final String code;
  final bool found;
  final String source;

  /// False when our pincode list marks the pincode inactive.
  final bool active;
  final PlaceRef? district;
  final PlaceRef? region;
  final PlaceRef? state;
  final PlaceRef? zone;

  /// The neighbourhood the map names ("Elathur"), when it has been located.
  final String area;
  final double? lat;
  final double? lng;

  const PincodeLookup({
    required this.code,
    required this.found,
    required this.source,
    this.active = true,
    this.district,
    this.region,
    this.state,
    this.zone,
    this.area = '',
    this.lat,
    this.lng,
  });

  bool get inOurList => source == 'master';
  bool get isSuggestion => source == 'geocode';

  /// "Kozhikode · Calicut · Kerala" — district, region, state; whatever of them is known.
  String get placeLine => [district, region, state]
      .whereType<PlaceRef>()
      .map((p) => p.name)
      .where((n) => n.isNotEmpty)
      .join(' · ');

  factory PincodeLookup.fromJson(Map<String, dynamic> j) => PincodeLookup(
    code: '${j['code'] ?? ''}',
    found: j['found'] == true,
    source: '${j['source'] ?? 'none'}',
    active: j['active'] != false,
    district: PlaceRef.tryParse(j['district']),
    region: PlaceRef.tryParse(j['region']),
    state: PlaceRef.tryParse(j['state']),
    zone: PlaceRef.tryParse(j['zone']),
    area: '${j['area'] ?? ''}',
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
  );
}
