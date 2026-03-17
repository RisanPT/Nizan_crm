/// A model class representing a single booking in the system.
class Booking {
  final String id;
  final String customerName;
  final String phone;
  final String email;
  final String service;
  final String region;
  final DateTime bookingDate; // The "record" / calendar date
  final DateTime serviceStart; // Start of service period
  final DateTime serviceEnd; // End of service period
  final double totalPrice;
  final double advanceAmount;

  const Booking({
    required this.id,
    required this.customerName,
    required this.phone,
    this.email = '',
    required this.service,
    this.region = '',
    required this.bookingDate,
    required this.serviceStart,
    required this.serviceEnd,
    required this.totalPrice,
    required this.advanceAmount,
  });

  /// Returns true if this booking falls on the given calendar date.
  bool isOnDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(serviceStart.year, serviceStart.month, serviceStart.day);
    final end = DateTime(serviceEnd.year, serviceEnd.month, serviceEnd.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  String get initials => customerName.isNotEmpty ? customerName[0].toUpperCase() : '?';
}
