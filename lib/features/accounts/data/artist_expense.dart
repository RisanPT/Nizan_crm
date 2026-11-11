import 'package:flutter/material.dart';
import 'package:nizan_crm/features/accounts/data/food_allowance.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart' show formatKm;
import 'artist_collection.dart'; // re-uses BookingRef

/// The meals an artist can file a food expense under.
const kMeals = <(String, String, IconData)>[
  ('breakfast', 'Breakfast', Icons.free_breakfast_outlined),
  ('lunch', 'Lunch', Icons.lunch_dining_outlined),
  ('snacks', 'Snacks / tea', Icons.local_cafe_outlined),
  ('dinner', 'Dinner', Icons.dinner_dining_outlined),
];

/// "Morning" / "Afternoon" / "Evening" — when in the day a work is (by the middle of it).
String periodLabel(String period) => switch (period) {
      'morning' => 'Morning',
      'afternoon' => 'Afternoon',
      'evening' => 'Evening',
      _ => '',
    };

/// "Lunch" — or, for a set of meals written as one key ("breakfast+lunch+dinner"), "Breakfast + Lunch + Dinner".
String mealLabel(String meal) {
  if (meal.contains('+')) return mealsLabel(meal.split('+'));
  return kMeals.where((m) => m.$1 == meal).map((m) => m.$2).firstOrNull ?? '';
}

/// "Breakfast + Lunch + Dinner" — the meals of one entry, in the order they are eaten.
String mealsLabel(Iterable<String> meals) =>
    orderMeals(meals).map(mealLabel).where((l) => l.isNotEmpty).join(' + ');

/// [meals] without repeats or unknown names, in the order the day goes: breakfast, lunch, snacks, dinner.
List<String> orderMeals(Iterable<String> meals) {
  final set = meals.toSet();
  return [for (final m in kMeals) if (set.contains(m.$1)) m.$1];
}

/// A food entry's meals as the server wants them: the meals, and the single [meal] ('' when
/// there are two or more, or none).
({List<String> meals, String meal}) mealFields(Iterable<String> meals) {
  final ordered = orderMeals(meals);
  return (meals: ordered, meal: ordered.length == 1 ? ordered.first : '');
}

/// "Travel distance 280 km" — how far the work is, for Accounts to judge an amount by;
/// '' when the booking has no distance recorded (nothing is shown rather than "0 km").
String travelDistanceText(double km) => km > 0 ? 'Travel distance ${formatKm(km)} km' : '';

/// The meal a time of day most likely was: before 11 breakfast, then lunch until 3:30 pm,
/// snacks until 6:30 pm, otherwise dinner.
String guessMeal(DateTime t) {
  final minutes = t.hour * 60 + t.minute;
  if (minutes < 11 * 60) return 'breakfast';
  if (minutes < 15 * 60 + 30) return 'lunch';
  if (minutes < 18 * 60 + 30) return 'snacks';
  return 'dinner';
}

/// One work's share of an expense.
class AllocationShare {
  final String bookingId;
  final String bookingNumber;
  final String customerName;
  final String service;
  final DateTime? serviceStart;
  final DateTime? serviceEnd;

  /// morning | afternoon | evening — when in the day this work is.
  final String period;
  final double amount;

  /// How far the work is (the booking's travel distance, km); 0 = not recorded.
  /// Accounts reads it beside the amount to judge it.
  final double travelDistanceKm;

  const AllocationShare({
    required this.bookingId,
    required this.bookingNumber,
    required this.customerName,
    required this.service,
    required this.serviceStart,
    required this.serviceEnd,
    required this.period,
    required this.amount,
    this.travelDistanceKm = 0,
  });

  factory AllocationShare.fromJson(Map<String, dynamic> j) => AllocationShare(
        bookingId: '${j['bookingId'] ?? ''}',
        bookingNumber: '${j['bookingNumber'] ?? ''}',
        customerName: '${j['customerName'] ?? ''}',
        service: '${j['service'] ?? ''}',
        serviceStart: DateTime.tryParse('${j['serviceStart'] ?? ''}')?.toLocal(),
        serviceEnd: DateTime.tryParse('${j['serviceEnd'] ?? ''}')?.toLocal(),
        period: '${j['period'] ?? ''}',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        travelDistanceKm: (j['travelDistanceKm'] as num?)?.toDouble() ?? 0,
      );
}

/// Where a FOOD expense belongs — the work it was eaten for, by the time of the meal
/// (the rule is the server's: utils/mealAllocation.js). Only sent to the Accounts screens.
class ExpenseAllocation {
  /// pinned (tied to a work by the artist) | time (nearest work in time) | single (the
  /// only work that day) | last (several meals in one entry, several works that day → the last
  /// work) | unallocated (no work that day) | unlinked (no meal recorded) | shoot
  final String mode;
  final bool counted;
  final String reason;

  /// 'far' when the meal was more than 4 hours from the nearest work.
  final String flag;
  final String meal;

  /// Every meal the entry covers (one, or several when it was filed as a combined bill).
  final List<String> meals;
  final DateTime? mealAt;
  final List<AllocationShare> shares;

  /// The team's limit for this meal on the work, and whether the team is over it (null when no
  /// allowance is set for the meal, or the expense is not placed under a work).
  final ExpenseLimit? limit;

  const ExpenseAllocation({
    required this.mode,
    required this.counted,
    required this.reason,
    required this.flag,
    required this.meal,
    this.meals = const [],
    required this.mealAt,
    required this.shares,
    this.limit,
  });

  bool get isPlaced => shares.isNotEmpty;
  bool get isPinned => mode == 'pinned';
  bool get isLast => mode == 'last';
  bool get isFar => flag == 'far';

  /// The meals of the entry: [meals], or the single [meal] of an older one.
  List<String> get effectiveMeals => meals.isNotEmpty ? orderMeals(meals) : (meal.isEmpty ? const [] : [meal]);

  factory ExpenseAllocation.fromJson(Map<String, dynamic> j) => ExpenseAllocation(
        mode: '${j['mode'] ?? ''}',
        counted: j['counted'] != false,
        reason: '${j['reason'] ?? ''}',
        flag: '${j['flag'] ?? ''}',
        meal: '${j['meal'] ?? ''}',
        meals: [for (final m in (j['meals'] as List? ?? const [])) '$m'],
        mealAt: DateTime.tryParse('${j['mealAt'] ?? ''}')?.toLocal(),
        shares: [for (final s in (j['shares'] as List? ?? const [])) AllocationShare.fromJson((s as Map).cast<String, dynamic>())],
        limit: j['limit'] is Map ? ExpenseLimit.fromJson((j['limit'] as Map).cast<String, dynamic>()) : null,
      );
}

class ArtistExpense {
  final String id;
  final Employee? employee;
  final BookingRef? booking;
  final String category; // food | travel | stay | materials | fuel | other

  /// For food: breakfast | lunch | snacks | dinner ('' = not recorded, or several — see [meals]).
  /// The time is [date].
  final String meal;

  /// Every meal the entry covers; empty on entries filed before several meals could be picked
  /// (use [effectiveMeals]).
  final List<String> meals;

  /// Which work a food expense belongs to — only when asked for (?withWorks=1).
  final ExpenseAllocation? allocation;

  /// Right after it was saved: is the team over its limit for this meal? (Only on the response to a
  /// create / edit.)
  final TeamMealCheck? limitCheck;
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
    this.meal = '',
    this.meals = const [],
    this.allocation,
    this.limitCheck,
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

  /// The meals of the entry in the order they are eaten: [meals], or the single [meal] of an older entry.
  List<String> get effectiveMeals => meals.isNotEmpty ? orderMeals(meals) : (meal.isEmpty ? const [] : [meal]);

  /// One bill for more than one meal.
  bool get isCombined => effectiveMeals.length > 1;

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
      meal: json['meal'] as String? ?? '',
      meals: [for (final m in (json['meals'] as List? ?? const [])) '$m'],
      allocation: json['allocation'] is Map ? ExpenseAllocation.fromJson((json['allocation'] as Map).cast<String, dynamic>()) : null,
      limitCheck: json['limitCheck'] is Map ? TeamMealCheck.fromJson((json['limitCheck'] as Map).cast<String, dynamic>()) : null,
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
