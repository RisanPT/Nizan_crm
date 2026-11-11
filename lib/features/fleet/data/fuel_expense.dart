import 'package:flutter/foundation.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'expense_km_check.dart';
import 'expense_split.dart';
import 'fuel_price.dart';
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
  final String billImage;
  final String status; // pending | approved | rejected
  final Vehicle? vehicle;
  final Employee? driver;

  /// The work (booking) this expense was for. Null = a whole-day expense,
  /// shared across that day's works.
  final String? bookingId;

  /// "BK-123 · Asha" for the linked work ('' when not linked).
  final String workLabel;

  /// The IST day it is filed under ('YYYY-MM-DD'; '' on older entries).
  final String dayKey;

  /// Where the linked work is — for Accounts' location check.
  final String workAddress;
  final String workPincode;

  /// Map link (or "lat, lng") the work was booked with.
  final String workMapUrl;

  /// Planned vs odometer km for that driver's day (null = no driver, e.g. a salary).
  final ExpenseKmCheck? kmCheck;

  /// Which work(s) it belongs to, who the artist is on each, and the share of each
  /// (null = no driver, or an older server).
  final ExpenseSplit? split;

  /// The bill's rate (amount ÷ litres) against the fuel price of its day — null when the server doesn't
  /// send one (an older server, a driver's own list, or not a fuel fill-up).
  final RateCheck? rateCheck;

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
    this.billImage = '',
    this.status = 'pending',
    this.vehicle,
    this.driver,
    this.bookingId,
    this.workLabel = '',
    this.dayKey = '',
    this.workAddress = '',
    this.workPincode = '',
    this.workMapUrl = '',
    this.kmCheck,
    this.split,
    this.rateCheck,
  });

  factory FuelExpense.fromJson(Map<String, dynamic> json) {
    final vehicleJson = json['vehicleId'];
    final driverJson = json['driverId'];
    // `bookingId` comes populated (an object) or as a bare id.
    final workJson = json['bookingId'];
    final workMap = workJson is Map<String, dynamic> ? workJson : null;
    final workId = workMap != null
        ? (workMap['_id'] ?? workMap['id'])?.toString()
        : workJson?.toString();

    final expense = FuelExpense(
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
      billImage: json['billImage'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      vehicle: vehicleJson is Map<String, dynamic>
          ? Vehicle.fromJson(vehicleJson)
          : null,
      driver: driverJson is Map<String, dynamic>
          ? Employee.fromJson(driverJson)
          : null,
      bookingId: (workId == null || workId.isEmpty) ? null : workId,
      workLabel: workMap == null
          ? ''
          : [workMap['bookingNumber'], workMap['customerName']]
              .where((x) => x != null && '$x'.trim().isNotEmpty)
              .join(' · '),
      dayKey: json['dayKey'] as String? ?? '',
      workAddress: (workMap?['address'] as String? ?? '').trim(),
      workPincode: (workMap?['pincode'] as String? ?? '').trim(),
      workMapUrl: (workMap?['mapUrl'] as String? ?? '').trim(),
      kmCheck: json['kmCheck'] is Map<String, dynamic>
          ? ExpenseKmCheck.fromJson(json['kmCheck'] as Map<String, dynamic>)
          : null,
      split: json['split'] is Map<String, dynamic>
          ? ExpenseSplit.fromJson(json['split'] as Map<String, dynamic>)
          : null,
      rateCheck: json['rateCheck'] is Map<String, dynamic>
          ? RateCheck.fromJson(json['rateCheck'] as Map<String, dynamic>)
          : null,
    );
    debugPrint('[FuelExpense] id=${expense.id} notes="${expense.notes}" raw_notes=${json['notes']}');
    return expense;
  }
}
