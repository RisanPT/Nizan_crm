import 'package:nizan_crm/core/models/employee.dart';
import 'artist_collection.dart'; // re-uses BookingRef

class ArtistExpense {
  final String id;
  final Employee? employee;
  final BookingRef? booking;
  final String category; // food | travel | stay | materials | fuel | other
  /// What the spend was for: 'bridal' (client work) or 'model_shoot'.
  final String workType;
  final double amount;
  final DateTime date;
  /// Event date stored on the bill itself (model-shoot bills). Bridal bills
  /// take it from [booking] instead — use [eventStart]/[eventEnd].
  final DateTime? eventDate;
  final String notes;
  final String receiptImage;
  final String status; // pending | verified | rejected
  final String? verifiedByName;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final String? ocrStatus;
  final double? ocrAmountFound;

  const ArtistExpense({
    required this.id,
    this.employee,
    this.booking,
    required this.category,
    this.workType = 'bridal',
    required this.amount,
    required this.date,
    this.eventDate,
    required this.notes,
    required this.receiptImage,
    required this.status,
    this.verifiedByName,
    this.verifiedAt,
    required this.createdAt,
    this.ocrStatus,
    this.ocrAmountFound,
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
      workType: json['workType'] as String? ?? 'bridal',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      eventDate: DateTime.tryParse(json['eventDate']?.toString() ?? '')?.toLocal(),
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
      ocrStatus: json['ocrStatus'] as String?,
      ocrAmountFound: (json['ocrAmountFound'] as num?)?.toDouble(),
    );
  }

  /// When the work took place: the linked booking's event, else [eventDate].
  DateTime? get eventStart => booking?.serviceStart ?? eventDate;

  /// Last day of a multi-day booking; null for a single day.
  DateTime? get eventEnd => booking?.serviceStart != null ? booking?.serviceEnd : null;
}
