import 'package:flutter/foundation.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart' show orderMeals;
import 'package:nizan_crm/features/accounts/data/food_allowance.dart';

// What each WORK cost, with an artist's food placed under the work it was eaten for by the
// time of the meal (the rule is the server's: utils/mealAllocation.js). Three views:
//   • MealPreview — the artist, while adding a meal: which of their works it would count under
//   • ArtistDay   — one artist's day as a timeline: works in order, the costs under each
//   • WorkCostPage — Accounts: cost per work over a period

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
DateTime? _t(Object? v) => DateTime.tryParse('${v ?? ''}')?.toLocal();

// ── the artist's preview while adding a meal ─────────────────────────────────

class DayWorkBrief {
  final String bookingId;
  final String bookingNumber;
  final String customerName;
  final String service;
  final DateTime? serviceStart;
  final DateTime? serviceEnd;

  /// morning | afternoon | evening — when in the day this work is.
  final String period;

  /// How far the work is (the booking's travel distance, km); 0 = not recorded.
  final double travelDistanceKm;

  const DayWorkBrief({
    required this.bookingId,
    required this.bookingNumber,
    required this.customerName,
    required this.service,
    required this.serviceStart,
    required this.serviceEnd,
    this.period = '',
    this.travelDistanceKm = 0,
  });

  factory DayWorkBrief.fromJson(Map<String, dynamic> j) => DayWorkBrief(
        bookingId: '${j['bookingId'] ?? ''}',
        bookingNumber: '${j['bookingNumber'] ?? ''}',
        customerName: '${j['customerName'] ?? ''}',
        service: '${j['service'] ?? ''}',
        serviceStart: _t(j['serviceStart']),
        serviceEnd: _t(j['serviceEnd']),
        period: '${j['period'] ?? ''}',
        travelDistanceKm: _d(j['travelDistanceKm']),
      );
}

class MealSuggestion {
  /// The work the meal would count under; null when there is none that day.
  final String? bookingId;

  /// time | single | last (several meals in one bill, several works that day → the last work) | unallocated
  final String mode;

  /// period (the work of the meal's time of day) | nearest (none that day, so the nearest work) | only | last | ''
  final String basis;

  /// The time of day the meal belongs to: morning | afternoon | evening.
  final String period;
  final String reason;
  final String flag;
  final int? minutes;

  const MealSuggestion({required this.bookingId, required this.mode, this.basis = '', this.period = '', required this.reason, required this.flag, required this.minutes});

  bool get hasWork => bookingId != null && bookingId!.isNotEmpty;
  bool get isFar => flag == 'far';
  bool get isLast => mode == 'last';

  factory MealSuggestion.fromJson(Map<String, dynamic> j) => MealSuggestion(
        bookingId: j['bookingId'] == null ? null : '${j['bookingId']}',
        mode: '${j['mode'] ?? ''}',
        basis: '${j['basis'] ?? ''}',
        period: '${j['period'] ?? ''}',
        reason: '${j['reason'] ?? ''}',
        flag: '${j['flag'] ?? ''}',
        minutes: (j['minutes'] as num?)?.toInt(),
      );
}

class MealPreview {
  final String dayKey;

  /// The artist's works that day, in time order.
  final List<DayWorkBrief> works;
  final MealSuggestion suggestion;

  /// The allowance per head for this meal and the heads on the suggested work; null when no allowance is set.
  final MealAllowanceHint? allowance;

  /// The team's limit for this meal on the work it will count under (the one the artist chose, else
  /// the suggested one) and what the team has already logged — what the form checks the amount against.
  final TeamMealState? team;

  const MealPreview({required this.dayKey, required this.works, required this.suggestion, this.allowance, this.team});

  DayWorkBrief? workById(String? id) => works.where((w) => w.bookingId == id).firstOrNull;

  factory MealPreview.fromJson(Map<String, dynamic> j) => MealPreview(
        dayKey: '${j['dayKey'] ?? ''}',
        works: [for (final w in (j['works'] as List? ?? const [])) DayWorkBrief.fromJson((w as Map).cast<String, dynamic>())],
        suggestion: MealSuggestion.fromJson(((j['suggestion'] as Map?) ?? const {}).cast<String, dynamic>()),
        allowance: j['allowance'] is Map ? MealAllowanceHint.fromJson((j['allowance'] as Map).cast<String, dynamic>()) : null,
        team: j['team'] is Map ? TeamMealState.fromJson((j['team'] as Map).cast<String, dynamic>()) : null,
      );
}

// ── one expense line under a work ────────────────────────────────────────────

class CostLine {
  final String expenseId;
  final String category;
  final String meal;

  /// Every meal the line covers (empty from an older server — use [effectiveMeals]).
  final List<String> meals;
  final DateTime? at;
  final double amount;
  final String status;
  final bool counted;
  final String notes;

  /// pinned | time | single | last | direct | unallocated | unlinked | shoot
  final String mode;
  final String reason;
  final String flag;

  /// Who spent it (cost-per-work report).
  final String artist;
  final String employeeId;

  const CostLine({
    required this.expenseId,
    required this.category,
    required this.meal,
    this.meals = const [],
    required this.at,
    required this.amount,
    required this.status,
    required this.counted,
    required this.notes,
    required this.mode,
    required this.reason,
    required this.flag,
    required this.artist,
    this.employeeId = '',
  });

  bool get isFood => category == 'food';
  bool get isFar => flag == 'far';

  /// The meals of the line: [meals], or the single [meal] of an older one.
  List<String> get effectiveMeals => meals.isNotEmpty ? orderMeals(meals) : (meal.isEmpty ? const [] : [meal]);

  factory CostLine.fromJson(Map<String, dynamic> j) => CostLine(
        expenseId: '${j['expenseId'] ?? ''}',
        category: '${j['category'] ?? 'other'}',
        meal: '${j['meal'] ?? ''}',
        meals: [for (final m in (j['meals'] as List? ?? const [])) '$m'],
        at: _t(j['at']),
        amount: _d(j['amount']),
        status: '${j['status'] ?? 'pending'}',
        counted: j['counted'] != false,
        notes: '${j['notes'] ?? ''}',
        mode: '${j['mode'] ?? ''}',
        reason: '${j['reason'] ?? ''}',
        flag: '${j['flag'] ?? ''}',
        artist: '${j['artist'] ?? ''}',
        employeeId: '${j['employeeId'] ?? ''}',
      );
}

// ── one artist's day ─────────────────────────────────────────────────────────

class DayWork {
  final String bookingId;
  final String bookingNumber;
  final String customerName;
  final String service;
  final DateTime? serviceStart;
  final DateTime? serviceEnd;
  final String place;

  /// morning | afternoon | evening — when in the day this work is.
  final String period;

  /// How far the work is (the booking's travel distance, km); 0 = not recorded.
  final double travelDistanceKm;

  /// A food expense the artist tied to this work although it is on another day.
  final bool outsideDay;
  final double food;
  final double other;
  final double total;
  final List<CostLine> expenses;

  const DayWork({
    required this.bookingId,
    required this.bookingNumber,
    required this.customerName,
    required this.service,
    required this.serviceStart,
    required this.serviceEnd,
    required this.place,
    this.period = '',
    this.travelDistanceKm = 0,
    required this.outsideDay,
    required this.food,
    required this.other,
    required this.total,
    required this.expenses,
  });

  factory DayWork.fromJson(Map<String, dynamic> j) => DayWork(
        bookingId: '${j['bookingId'] ?? ''}',
        bookingNumber: '${j['bookingNumber'] ?? ''}',
        customerName: '${j['customerName'] ?? ''}',
        service: '${j['service'] ?? ''}',
        serviceStart: _t(j['serviceStart']),
        serviceEnd: _t(j['serviceEnd']),
        place: '${j['place'] ?? ''}',
        period: '${j['period'] ?? ''}',
        travelDistanceKm: _d(j['travelDistanceKm']),
        outsideDay: j['outsideDay'] == true,
        food: _d(j['food']),
        other: _d(j['other']),
        total: _d(j['total']),
        expenses: [for (final e in (j['expenses'] as List? ?? const [])) CostLine.fromJson((e as Map).cast<String, dynamic>())],
      );
}

class DayTotals {
  final double food;
  final double other;
  final double all;
  final double unplaced;
  const DayTotals({required this.food, required this.other, required this.all, required this.unplaced});

  factory DayTotals.fromJson(Map<String, dynamic> j) =>
      DayTotals(food: _d(j['food']), other: _d(j['other']), all: _d(j['all']), unplaced: _d(j['unplaced']));
}

class ArtistDay {
  final String employeeId;
  final String employeeName;
  final String dayKey;

  /// The artist's works in time order, each with the costs placed under it.
  final List<DayWork> works;

  /// What could not be placed under a work (no meal recorded, no work that day, a model shoot…).
  final List<CostLine> unplaced;
  final DayTotals totals;

  const ArtistDay({
    required this.employeeId,
    required this.employeeName,
    required this.dayKey,
    required this.works,
    required this.unplaced,
    required this.totals,
  });

  factory ArtistDay.fromJson(Map<String, dynamic> j) {
    final emp = ((j['employee'] as Map?) ?? const {}).cast<String, dynamic>();
    return ArtistDay(
      employeeId: '${emp['id'] ?? ''}',
      employeeName: '${emp['name'] ?? ''}',
      dayKey: '${j['dayKey'] ?? ''}',
      works: [for (final w in (j['works'] as List? ?? const [])) DayWork.fromJson((w as Map).cast<String, dynamic>())],
      unplaced: [for (final e in (j['unplaced'] as List? ?? const [])) CostLine.fromJson((e as Map).cast<String, dynamic>())],
      totals: DayTotals.fromJson(((j['totals'] as Map?) ?? const {}).cast<String, dynamic>()),
    );
  }
}

// ── cost per work (Accounts) ─────────────────────────────────────────────────

/// Someone on a work, and what they spent on food for it.
class WorkPerson {
  final String employeeId;
  final String name;

  /// lead | assistant | '' (spent on the work without being assigned to it)
  final String roleType;

  /// Assigned to the work — a "head" for the per-head cost.
  final bool assigned;
  final double food;

  const WorkPerson({required this.employeeId, required this.name, required this.roleType, required this.assigned, required this.food});

  String get roleLabel => switch (roleType) {
        'lead' => 'Lead',
        'assistant' => 'Assistant',
        _ => 'Not assigned',
      };

  factory WorkPerson.fromJson(Map<String, dynamic> j) => WorkPerson(
        employeeId: '${j['employeeId'] ?? ''}',
        name: '${j['name'] ?? ''}',
        roleType: '${j['roleType'] ?? ''}',
        assigned: j['assigned'] != false,
        food: _d(j['food']),
      );
}

class WorkCostRow {
  final String bookingId;
  final String bookingNumber;
  final String customerName;
  final String service;
  final DateTime? serviceStart;

  /// morning | afternoon | evening — when in the day this work is.
  final String period;

  /// How far the work is (the booking's travel distance, km); 0 = not recorded.
  final double travelDistanceKm;
  final List<String> artists;
  final double food;
  final double travel;
  final double stay;
  final double materials;
  final double fuel;
  final double other;
  final double total;
  final int expenseCount;
  final int pendingCount;
  final List<CostLine> lines;

  /// Everyone assigned to the work (lead + assistants) — the divisor for the per-head cost.
  final int heads;

  /// The work's food ÷ [heads]; null when nobody is assigned.
  final double? foodPerHead;

  /// Who is on the work and what each spent on food (people who filed none show ₹0).
  final List<WorkPerson> people;

  /// The work's food, meal by meal, against heads × the allowance per head.
  final AllowanceCheck allowance;

  const WorkCostRow({
    required this.bookingId,
    required this.bookingNumber,
    required this.customerName,
    required this.service,
    required this.serviceStart,
    this.period = '',
    this.travelDistanceKm = 0,
    required this.artists,
    required this.food,
    required this.travel,
    required this.stay,
    required this.materials,
    required this.fuel,
    required this.other,
    required this.total,
    required this.expenseCount,
    required this.pendingCount,
    required this.lines,
    this.heads = 0,
    this.foodPerHead,
    this.people = const [],
    this.allowance = AllowanceCheck.none,
  });

  /// Everything but food.
  double get nonFood => total - food;

  factory WorkCostRow.fromJson(Map<String, dynamic> j) => WorkCostRow(
        bookingId: '${j['bookingId'] ?? ''}',
        bookingNumber: '${j['bookingNumber'] ?? ''}',
        customerName: '${j['customerName'] ?? ''}',
        service: '${j['service'] ?? ''}',
        serviceStart: _t(j['serviceStart']),
        period: '${j['period'] ?? ''}',
        travelDistanceKm: _d(j['travelDistanceKm']),
        artists: [for (final a in (j['artists'] as List? ?? const [])) '$a'],
        food: _d(j['food']),
        travel: _d(j['travel']),
        stay: _d(j['stay']),
        materials: _d(j['materials']),
        fuel: _d(j['fuel']),
        other: _d(j['other']),
        total: _d(j['total']),
        expenseCount: (j['expenseCount'] as num?)?.toInt() ?? 0,
        pendingCount: (j['pendingCount'] as num?)?.toInt() ?? 0,
        lines: [for (final l in (j['lines'] as List? ?? const [])) CostLine.fromJson((l as Map).cast<String, dynamic>())],
        heads: (j['heads'] as num?)?.toInt() ?? 0,
        foodPerHead: (j['foodPerHead'] as num?)?.toDouble(),
        people: [for (final p in (j['people'] as List? ?? const [])) WorkPerson.fromJson((p as Map).cast<String, dynamic>())],
        allowance: j['allowance'] is Map ? AllowanceCheck.fromJson((j['allowance'] as Map).cast<String, dynamic>()) : AllowanceCheck.none,
      );
}

class WorkCostTotals {
  final double food;
  final double other;
  final double total;

  /// Spend that could not be placed under a work, and how many entries that is.
  final double unplaced;
  final int unplacedCount;

  /// How many works are over the food allowance, and by how much in all.
  final int overAllowanceCount;
  final double overAllowanceAmount;

  const WorkCostTotals({
    required this.food,
    required this.other,
    required this.total,
    required this.unplaced,
    required this.unplacedCount,
    this.overAllowanceCount = 0,
    this.overAllowanceAmount = 0,
  });
  static const zero = WorkCostTotals(food: 0, other: 0, total: 0, unplaced: 0, unplacedCount: 0);

  factory WorkCostTotals.fromJson(Map<String, dynamic> j) => WorkCostTotals(
        food: _d(j['food']),
        other: _d(j['other']),
        total: _d(j['total']),
        unplaced: _d(j['unplaced']),
        unplacedCount: (j['unplacedCount'] as num?)?.toInt() ?? 0,
        overAllowanceCount: (j['overAllowanceCount'] as num?)?.toInt() ?? 0,
        overAllowanceAmount: _d(j['overAllowanceAmount']),
      );
}

class WorkCostPage {
  final List<WorkCostRow> items;
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
  final WorkCostTotals totals;

  /// More expenses matched than the server reads at once, so the figures are partial.
  final bool truncated;

  const WorkCostPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.totals,
    required this.truncated,
  });

  factory WorkCostPage.fromJson(Map<String, dynamic> j) => WorkCostPage(
        items: [for (final w in (j['items'] as List? ?? const [])) WorkCostRow.fromJson((w as Map).cast<String, dynamic>())],
        page: (j['page'] as num?)?.toInt() ?? 1,
        limit: (j['limit'] as num?)?.toInt() ?? 20,
        totalItems: (j['totalItems'] as num?)?.toInt() ?? 0,
        totalPages: (j['totalPages'] as num?)?.toInt() ?? 1,
        totals: j['totals'] is Map ? WorkCostTotals.fromJson((j['totals'] as Map).cast<String, dynamic>()) : WorkCostTotals.zero,
        truncated: j['truncated'] == true,
      );
}

/// What to look at in the cost-per-work report. An immutable value: equal queries are the
/// same cached request.
@immutable
class WorkCostQuery {
  /// 'YYYY-MM-DD' (inclusive), or null = no limit on that side.
  final String? from;
  final String? to;
  final String? employeeId;

  /// pending | verified | rejected — rejected bills are not a cost, so the default leaves them out.
  final Set<String> statuses;
  final String search;
  final int page;
  final int limit;

  const WorkCostQuery({
    this.from,
    this.to,
    this.employeeId,
    this.statuses = const {'pending', 'verified'},
    this.search = '',
    this.page = 1,
    this.limit = 20,
  });

  WorkCostQuery copyWith({
    Object? from = _unset,
    Object? to = _unset,
    Object? employeeId = _unset,
    Set<String>? statuses,
    String? search,
    int? page,
    int? limit,
  }) =>
      WorkCostQuery(
        from: identical(from, _unset) ? this.from : from as String?,
        to: identical(to, _unset) ? this.to : to as String?,
        employeeId: identical(employeeId, _unset) ? this.employeeId : employeeId as String?,
        statuses: statuses ?? this.statuses,
        search: search ?? this.search,
        page: page ?? this.page,
        limit: limit ?? this.limit,
      );

  /// A change of what is being looked at goes back to the first page.
  WorkCostQuery refiltered({
    Object? from = _unset,
    Object? to = _unset,
    Object? employeeId = _unset,
    Set<String>? statuses,
    String? search,
    int? limit,
  }) =>
      copyWith(from: from, to: to, employeeId: employeeId, statuses: statuses, search: search, limit: limit, page: 1);

  Map<String, String> toParams({bool export = false}) => {
        'from': ?from,
        'to': ?to,
        'employeeId': ?employeeId,
        'status': (statuses.toList()..sort()).join(','),
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (export) 'export': '1' else ...{'page': '$page', 'limit': '$limit'},
      };

  @override
  bool operator ==(Object other) =>
      other is WorkCostQuery &&
      other.from == from &&
      other.to == to &&
      other.employeeId == employeeId &&
      setEquals(other.statuses, statuses) &&
      other.search == search &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(from, to, employeeId, Object.hashAllUnordered(statuses), search, page, limit);
}

const _unset = Object();
