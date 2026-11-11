import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import 'package:nizan_crm/features/fleet/data/vehicle_categories.dart';

String _plain(double? v) {
  if (v == null || v <= 0) return '';
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// The text fields behind a vehicle's category / seats / fuel-efficiency
/// details, so the Add / Edit dialog only needs to create one of these, show
/// [VehicleProfileFields], validate, and read the values back.
class VehicleProfileForm {
  VehicleProfileForm(Vehicle? vehicle)
      : category = vehicle?.category ?? '',
        seats = TextEditingController(
            text: (vehicle?.seats ?? 0) > 0 ? '${vehicle!.seats}' : ''),
        ratedMileage = TextEditingController(text: _plain(vehicle?.ratedMileage)),
        tankCapacity = TextEditingController(text: _plain(vehicle?.tankCapacity)),
        _hadMileage = (vehicle?.ratedMileage ?? 0) > 0,
        _hadTank = (vehicle?.tankCapacity ?? 0) > 0,
        _hadSeats = (vehicle?.seats ?? 0) > 0;

  /// '' = not set.
  String category;
  final TextEditingController seats;
  final TextEditingController ratedMileage;
  final TextEditingController tankCapacity;

  // Whether the vehicle already had a value, so clearing the box clears it
  // (sends 0) instead of "leave as it is".
  final bool _hadMileage;
  final bool _hadTank;
  final bool _hadSeats;

  void dispose() {
    seats.dispose();
    ratedMileage.dispose();
    tankCapacity.dispose();
  }

  static double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', ''));

  /// A message to show the user, or null when everything is fine.
  String? validate() {
    final s = seats.text.trim();
    if (s.isNotEmpty) {
      final n = int.tryParse(s);
      if (n == null || n < 0 || n > 60) return 'Seats must be a whole number between 0 and 60.';
    }
    final m = ratedMileage.text.trim();
    if (m.isNotEmpty) {
      final n = _parse(m);
      if (n == null || n < 0 || n > 500) return 'Rated mileage must be a number between 0 and 500.';
    }
    final t = tankCapacity.text.trim();
    if (t.isNotEmpty) {
      final n = _parse(t);
      if (n == null || n < 0 || n > 1000) return 'Tank capacity must be a number between 0 and 1000.';
    }
    return null;
  }

  /// null = leave as it is (new vehicle with nothing typed: the server then fills
  /// in the category's usual seats).
  int? get seatsValue {
    final s = seats.text.trim();
    if (s.isEmpty) return _hadSeats ? 0 : null;
    return int.tryParse(s);
  }

  double? get ratedMileageValue {
    final m = ratedMileage.text.trim();
    if (m.isEmpty) return _hadMileage ? 0 : null;
    return _parse(m);
  }

  double? get tankCapacityValue {
    final t = tankCapacity.text.trim();
    if (t.isEmpty) return _hadTank ? 0 : null;
    return _parse(t);
  }
}

/// Category, seats, rated mileage and tank capacity inputs for the vehicle dialog.
class VehicleProfileFields extends StatelessWidget {
  final VehicleProfileForm form;
  final String fuelType;

  /// Called after the category changes (the parent rebuilds its dialog).
  final VoidCallback onChanged;

  const VehicleProfileFields({
    super.key,
    required this.form,
    required this.fuelType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final mileage = mileageUnit(fuelType);
    final qty = fuelQuantityUnit(fuelType);
    final decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('vehicleCategory'),
          isExpanded: true,
          initialValue: vehicleCategoryByKey(form.category) == null ? '' : form.category,
          decoration: const InputDecoration(
            labelText: 'Category',
            helperText: 'Taxi / sedan, XL, MPV… decides which team size it suits.',
            helperMaxLines: 2,
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('Not set')),
            for (final c in vehicleCategories)
              DropdownMenuItem(
                value: c.key,
                child: Text(
                  c.seats > 0 ? '${c.label} · ${c.seats} seats' : c.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          // The closed field shows just the name; the seats are in the open list
          // (and in the Passenger seats box below).
          selectedItemBuilder: (context) => [
            const Text('Not set'),
            for (final c in vehicleCategories) Text(c.label, overflow: TextOverflow.ellipsis),
          ],
          onChanged: (value) {
            if (value == null) return;
            // Bring the category's usual seat count along, unless the user typed their own.
            final previousDefault = defaultSeatsFor(form.category);
            final typed = int.tryParse(form.seats.text.trim());
            if (form.seats.text.trim().isEmpty || typed == previousDefault) {
              final next = defaultSeatsFor(value);
              form.seats.text = next > 0 ? '$next' : '';
            }
            form.category = value;
            onChanged();
          },
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('vehicleSeats'),
                controller: form.seats,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Passenger seats',
                  helperText: 'Besides the driver',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                key: const Key('vehicleTank'),
                controller: form.tankCapacity,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [decimal],
                decoration: InputDecoration(
                  labelText: 'Tank ($qty)',
                  helperText: 'When full',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('vehicleRatedMileage'),
          controller: form.ratedMileage,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [decimal],
          decoration: InputDecoration(
            labelText: 'Rated mileage ($mileage)',
            helperText: 'The expected figure. Real mileage is worked out from fuel entries '
                'and compared with it.',
            helperMaxLines: 3,
          ),
        ),
      ],
    );
  }
}
