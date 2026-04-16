import 'employee.dart';
import 'vehicle.dart';

class FuelExpense {
  final String id;
  final String category;
  final DateTime date;
  final double odometerKm;
  final double liters;
  final double totalAmount;
  final String paymentMode;
  final String station;
  final String notes;
  final Vehicle? vehicle;
  final Employee? driver;

  const FuelExpense({
    required this.id,
    required this.category,
    required this.date,
    required this.odometerKm,
    required this.liters,
    required this.totalAmount,
    required this.paymentMode,
    required this.station,
    required this.notes,
    this.vehicle,
    this.driver,
  });

  factory FuelExpense.fromJson(Map<String, dynamic> json) {
    final vehicleJson = json['vehicleId'];
    final driverJson = json['driverId'];

    return FuelExpense(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'fuel',
      date:
          DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      odometerKm: (json['odometerKm'] as num?)?.toDouble() ?? 0,
      liters: (json['liters'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      paymentMode: json['paymentMode'] as String? ?? 'cash',
      station: json['station'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      vehicle: vehicleJson is Map<String, dynamic>
          ? Vehicle.fromJson(vehicleJson)
          : null,
      driver: driverJson is Map<String, dynamic>
          ? Employee.fromJson(driverJson)
          : null,
    );
  }
}
