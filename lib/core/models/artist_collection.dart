import 'employee.dart';

class BookingRef {
  final String id;
  final String bookingNumber;
  final String customerName;
  final String service;

  const BookingRef({
    required this.id,
    required this.bookingNumber,
    required this.customerName,
    required this.service,
  });

  factory BookingRef.fromJson(Map<String, dynamic> json) {
    return BookingRef(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      bookingNumber: json['bookingNumber'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      service: json['service'] as String? ?? '',
    );
  }
}

class ArtistCollection {
  final String id;
  final BookingRef? booking;
  final Employee? employee;
  final double amount;
  final DateTime date;
  final String paymentMode;
  final String notes;
  final String status; // pending | verified | rejected
  final String? verifiedByName;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  const ArtistCollection({
    required this.id,
    this.booking,
    this.employee,
    required this.amount,
    required this.date,
    required this.paymentMode,
    required this.notes,
    required this.status,
    this.verifiedByName,
    this.verifiedAt,
    required this.createdAt,
  });

  factory ArtistCollection.fromJson(Map<String, dynamic> json) {
    final bookingJson = json['bookingId'];
    final employeeJson = json['employeeId'];
    final verifiedByJson = json['verifiedBy'];

    return ArtistCollection(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      booking: bookingJson is Map<String, dynamic>
          ? BookingRef.fromJson(bookingJson)
          : null,
      employee: employeeJson is Map<String, dynamic>
          ? Employee.fromJson(employeeJson)
          : null,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      paymentMode: json['paymentMode'] as String? ?? 'cash',
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      verifiedByName: verifiedByJson is Map<String, dynamic>
          ? verifiedByJson['name'] as String?
          : null,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'].toString())
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
