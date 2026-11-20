// COUNTRIES AND CITIES — the marketing geography a lead is placed in (GET /api/countries). Country → City; the India-only
// zone / state / region / district list used for pricing and field work is a different tree and is not touched.

/// The sign a currency is written with; the code itself when we do not know a sign.
String currencySign(String code) => switch (code.trim().toUpperCase()) {
  'INR' => '₹',
  'AED' => 'AED ',
  'MYR' => 'RM ',
  'USD' => r'$',
  'GBP' => '£',
  'EUR' => '€',
  'SAR' => 'SAR ',
  '' => '₹',
  final other => '$other ',
};

class MarketCity {
  const MarketCity({required this.id, required this.name, this.state = '', this.status = 'active', this.leads});
  final String id, name, state, status;

  /// How many leads are placed here — only when a manager asked for the full list.
  final int? leads;
  bool get isActive => status == 'active';

  factory MarketCity.fromJson(Map<String, dynamic> j) => MarketCity(
    id: '${j['id'] ?? ''}',
    name: '${j['name'] ?? ''}',
    state: '${j['state'] ?? ''}',
    status: '${j['status'] ?? 'active'}',
    leads: (j['leads'] as num?)?.toInt(),
  );
}

class MarketCountry {
  const MarketCountry({
    required this.id,
    required this.name,
    this.code = '',
    this.dialCode = '',
    this.currency = '',
    this.status = 'active',
    this.leads,
    this.cities = const [],
  });
  final String id, name, code, dialCode, currency, status;
  final int? leads;
  final List<MarketCity> cities;
  bool get isActive => status == 'active';

  factory MarketCountry.fromJson(Map<String, dynamic> j) => MarketCountry(
    id: '${j['id'] ?? ''}',
    name: '${j['name'] ?? ''}',
    code: '${j['code'] ?? ''}',
    dialCode: '${j['dialCode'] ?? ''}',
    currency: '${j['currency'] ?? ''}',
    status: '${j['status'] ?? 'active'}',
    leads: (j['leads'] as num?)?.toInt(),
    cities: [for (final c in (j['cities'] as List? ?? const [])) MarketCity.fromJson(Map<String, dynamic>.from(c as Map))],
  );

  /// "IN · +91 · INR" — whatever of it is filled in.
  String get detail => [code, dialCode, currency].where((s) => s.isNotEmpty).join(' · ');
}

/// What the list returns: the countries, and whether this user may change them.
class MarketList {
  const MarketList({this.countries = const [], this.canManage = false});
  final List<MarketCountry> countries;
  final bool canManage;

  factory MarketList.fromJson(Object? data) {
    final j = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
    return MarketList(
      countries: [for (final c in (j['countries'] as List? ?? const [])) MarketCountry.fromJson(Map<String, dynamic>.from(c as Map))],
      canManage: j['canManage'] == true,
    );
  }

  MarketCountry? country(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in countries) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The country a city is in (null when the city is not in the list, e.g. switched off).
  MarketCountry? countryOfCity(String? cityId) {
    if (cityId == null || cityId.isEmpty) return null;
    for (final c in countries) {
      if (c.cities.any((k) => k.id == cityId)) return c;
    }
    return null;
  }

  MarketCity? city(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in countries) {
      for (final k in c.cities) {
        if (k.id == id) return k;
      }
    }
    return null;
  }
}
