import 'employee.dart';

class Vehicle {
  final String id;
  final String name;
  final String registrationNumber;
  final String type;
  final String brand;
  final String fuelType;
  final String status;
  final String notes;
  final Employee? driver;

  const Vehicle({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.type,
    required this.brand,
    required this.fuelType,
    required this.status,
    required this.notes,
    this.driver,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final driverJson = json['driverId'];

    return Vehicle(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      registrationNumber: json['registrationNumber'] as String? ?? '',
      type: json['type'] as String? ?? 'car',
      brand: json['brand'] as String? ?? '',
      fuelType: json['fuelType'] as String? ?? 'petrol',
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String? ?? '',
      driver: driverJson is Map<String, dynamic>
          ? Employee.fromJson(driverJson)
          : null,
    );
  }
}
