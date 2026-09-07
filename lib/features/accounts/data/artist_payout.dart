import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart' show BookingRef;

/// A per-booking fee owed to an OUTSOURCE (freelance) artist. Freelancers are
/// paid per job via this record — never on monthly payroll. Lifecycle:
/// pending → approved → paid (paying posts a COGS expense to the ledger).
class ArtistPayout {
  final String id;
  final Employee? employee;
  final String employeeName;
  final BookingRef? booking;
  final String bookingNumber;
  final double amount;
  final DateTime date;
  final String paymentMode; // cash | upi | bank_transfer | other
  final String notes;
  final String status; // pending | approved | paid | cancelled
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? paidByName;
  final DateTime? paidAt;
  final DateTime createdAt;

  const ArtistPayout({
    required this.id,
    this.employee,
    this.employeeName = '',
    this.booking,
    this.bookingNumber = '',
    required this.amount,
    required this.date,
    this.paymentMode = 'bank_transfer',
    this.notes = '',
    this.status = 'pending',
    this.approvedByName,
    this.approvedAt,
    this.paidByName,
    this.paidAt,
    required this.createdAt,
  });

  /// Display name for the artist — the populated Employee, else the snapshot.
  String get artistName =>
      employee?.name.isNotEmpty == true ? employee!.name : employeeName;

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory ArtistPayout.fromJson(Map<String, dynamic> json) {
    return ArtistPayout(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      employee: json['employeeId'] is Map<String, dynamic>
          ? Employee.fromJson(json['employeeId'] as Map<String, dynamic>)
          : null,
      employeeName: json['employeeName'] as String? ?? '',
      booking: json['bookingId'] is Map<String, dynamic>
          ? BookingRef.fromJson(json['bookingId'] as Map<String, dynamic>)
          : null,
      bookingNumber: json['bookingNumber'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: _dt(json['date']) ?? DateTime.now(),
      paymentMode: json['paymentMode'] as String? ?? 'bank_transfer',
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      approvedByName: json['approvedBy'] is Map
          ? json['approvedBy']['name'] as String?
          : null,
      approvedAt: _dt(json['approvedAt']),
      paidByName:
          json['paidBy'] is Map ? json['paidBy']['name'] as String? : null,
      paidAt: _dt(json['paidAt']),
      createdAt: _dt(json['createdAt']) ?? DateTime.now(),
    );
  }
}
