// Vehicle categories — mirrors the backend list (utils/vehicleCategories.js);
// keep the two in step.
//
// `seats` = passengers the vehicle takes BESIDES the driver. It is only the
// default: each vehicle stores its own seat count.

class VehicleCategory {
  final String key;
  final String label;
  final int seats;
  const VehicleCategory(this.key, this.label, this.seats);
}

const vehicleCategories = <VehicleCategory>[
  VehicleCategory('hatchback', 'Hatchback', 4),
  VehicleCategory('sedan', 'Sedan / Taxi', 4),
  VehicleCategory('suv', 'SUV', 4),
  VehicleCategory('xl', 'XL (Innova / Ertiga type)', 6),
  VehicleCategory('mpv', 'MPV', 7),
  VehicleCategory('tempo_traveller', 'Tempo Traveller', 12),
  VehicleCategory('bike', 'Bike', 1),
  VehicleCategory('other', 'Other', 0),
];

VehicleCategory? vehicleCategoryByKey(String key) {
  for (final c in vehicleCategories) {
    if (c.key == key) return c;
  }
  return null;
}

/// Display name of a category key ('' when not set / unknown).
String vehicleCategoryLabel(String key) => vehicleCategoryByKey(key)?.label ?? '';

/// Short name for chips: "Sedan / Taxi" → "Sedan", "XL (Innova…)" → "XL".
String vehicleCategoryShortLabel(String key) {
  final label = vehicleCategoryLabel(key);
  if (label.isEmpty) return '';
  return label.split(RegExp(r'\s*[/(]')).first.trim();
}

int defaultSeatsFor(String key) => vehicleCategoryByKey(key)?.seats ?? 0;

// The sizes recommended for a team, smallest first.
const _suggestOrder = ['sedan', 'xl', 'mpv', 'tempo_traveller'];

/// The smallest recommended category that takes [people] passengers (artists and
/// assistants going to the work — the driver is not counted). `needsMultiple` is
/// true when even the largest vehicle is too small.
({VehicleCategory category, bool needsMultiple}) suggestVehicleCategory(int people) {
  final n = people < 0 ? 0 : people;
  for (final key in _suggestOrder) {
    final c = vehicleCategoryByKey(key)!;
    if (c.seats >= n) return (category: c, needsMultiple: false);
  }
  return (category: vehicleCategoryByKey(_suggestOrder.last)!, needsMultiple: true);
}

/// Does a vehicle with [seats] passenger seats take [people]? null = its
/// capacity isn't recorded, so we can't say.
bool? seatsFit(int seats, int people) {
  if (seats <= 0) return null;
  return seats >= (people < 0 ? 0 : people);
}

/// km / l for petrol & diesel (and hybrid / other), km / kg for CNG, km / kWh for electric.
String mileageUnit(String fuelType) =>
    fuelType == 'electric' ? 'km/kWh' : (fuelType == 'cng' ? 'km/kg' : 'km/l');

/// "litres" / "kg" / "kWh" — what the tank takes and what a fill-up is measured in.
String fuelQuantityUnit(String fuelType) =>
    fuelType == 'electric' ? 'kWh' : (fuelType == 'cng' ? 'kg' : 'L');
