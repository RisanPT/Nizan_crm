import 'employee.dart';
import 'artist_collection.dart'; // re-uses BookingRef

class ArtistExpense {
  final String id;
  final Employee? employee;
  final BookingRef? booking;
  final String category; // food | travel | stay | materials | fuel | other
  final double amount;
  final DateTime date;
  final String notes;
  final String receiptImage;
  final String status; // pending | verified | rejected
  final String? verifiedByName;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  const ArtistExpense({
    required this.id,
    this.employee,
    this.booking,
    required this.category,
    required this.amount,
    required this.date,
    required this.notes,
    required this.receiptImage,
    required this.status,
    this.verifiedByName,
    this.verifiedAt,
    required this.createdAt,
  });

  factory ArtistExpense.fromJson(Map<String, dynamic> json) {
    final employeeJson = json['employeeId'];
    final bookingJson = json['bookingId'];
    final verifiedByJson = json['verifiedBy'];

    return ArtistExpense(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      employee: employeeJson is Map<String, dynamic>
          ? Employee.fromJson(employeeJson)
          : null,
      booking: bookingJson is Map<String, dynamic>
          ? BookingRef.fromJson(bookingJson)
          : null,
      category: json['category'] as String? ?? 'other',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      notes: json['notes'] as String? ?? '',
      receiptImage: json['receiptImage'] as String? ?? '',
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
