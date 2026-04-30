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
  final String? attachmentUrl;
  final DateTime createdAt;
  final String? ocrStatus;
  final double? ocrAmountFound;

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
    this.attachmentUrl,
    required this.createdAt,
    this.ocrStatus,
    this.ocrAmountFound,
  });

  factory ArtistCollection.fromJson(Map<String, dynamic> json) {
    return ArtistCollection(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      booking: json['bookingId'] != null
          ? BookingRef.fromJson(json['bookingId'] as Map<String, dynamic>)
          : null,
      employee: json['employeeId'] != null
          ? Employee.fromJson(json['employeeId'] as Map<String, dynamic>)
          : null,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      paymentMode: json['paymentMode'] as String? ?? 'cash',
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      verifiedByName: json['verifiedBy']?['name'] as String?,
      verifiedAt: json['verifiedAt'] != null ? DateTime.parse(json['verifiedAt'] as String) : null,
      attachmentUrl: json['attachmentUrl'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      ocrStatus: json['ocrStatus'] as String?,
      ocrAmountFound: (json['ocrAmountFound'] as num?)?.toDouble(),
    );
  }
}
