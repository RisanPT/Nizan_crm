import 'package:flutter/foundation.dart';

// The FOOD ALLOWANCE per head. Accounts sets how much may be spent on each meal per person
// (the rule is the server's: utils/foodAllowance.js); a work's food is checked meal by meal
// against heads × the allowance. Over is flagged, never cut.

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
List<String> _meals(Object? v) => [for (final m in (v as List? ?? const [])) '$m'];

/// One allowance rule: a meal, an amount per head and (optionally) the dates it applies to.
@immutable
class FoodAllowanceRule {
  final String id;

  /// breakfast | lunch | snacks | dinner
  final String meal;
  final double amountPerHead;

  /// 'YYYY-MM-DD' (IST); '' = no limit on that side.
  final String effectiveFrom;
  final String effectiveTo;
  final bool active;
  final String note;

  const FoodAllowanceRule({
    required this.id,
    required this.meal,
    required this.amountPerHead,
    this.effectiveFrom = '',
    this.effectiveTo = '',
    this.active = true,
    this.note = '',
  });

  factory FoodAllowanceRule.fromJson(Map<String, dynamic> j) =>
      FoodAllowanceRule(
        id: '${j['_id'] ?? j['id'] ?? ''}',
        meal: '${j['meal'] ?? ''}',
        amountPerHead: _d(j['amountPerHead']),
        effectiveFrom: '${j['effectiveFrom'] ?? ''}',
        effectiveTo: '${j['effectiveTo'] ?? ''}',
        active: j['active'] != false,
        note: '${j['note'] ?? ''}',
      );

  Map<String, Object> toBody() => {
    'meal': meal,
    'amountPerHead': amountPerHead,
    'effectiveFrom': effectiveFrom,
    'effectiveTo': effectiveTo,
    'active': active,
    'note': note,
  };
}

/// One meal of a work, checked against the allowance.
class MealAllowanceCheck {
  /// One meal ('lunch'), or — for a bill that covers several — their key ('breakfast+lunch+dinner').
  final String meal;

  /// The meals this row covers (several when entries were filed for more than one meal at once and
  /// are checked together against the sum of their allowances). Empty from an older server.
  final List<String> meals;
  final double actual;

  /// The allowance per head for it, and heads × that; null when no rule / nobody assigned.
  final double? allowancePerHead;
  final double? allowed;
  final double over;

  /// over | within | no_rule | no_heads
  final String status;

  const MealAllowanceCheck({
    required this.meal,
    this.meals = const [],
    required this.actual,
    required this.allowancePerHead,
    required this.allowed,
    required this.over,
    required this.status,
  });

  bool get isOver => status == 'over';

  /// More than one meal checked together.
  bool get isPool => meals.length > 1 || meal.contains('+');

  factory MealAllowanceCheck.fromJson(Map<String, dynamic> j) =>
      MealAllowanceCheck(
        meal: '${j['meal'] ?? ''}',
        meals: _meals(j['meals']),
        actual: _d(j['actual']),
        allowancePerHead: (j['allowancePerHead'] as num?)?.toDouble(),
        allowed: (j['allowed'] as num?)?.toDouble(),
        over: _d(j['over']),
        status: '${j['status'] ?? ''}',
      );
}

/// A work's food against the allowance.
class AllowanceCheck {
  final List<MealAllowanceCheck> meals;

  /// Over the meals that have a rule (the ones that were checked).
  final double allowed;
  final double actual;
  final double over;
  final bool hasOver;

  /// Food with no meal recorded: spent, but it cannot be checked against a per-meal allowance.
  final double noMeal;

  const AllowanceCheck({
    required this.meals,
    required this.allowed,
    required this.actual,
    required this.over,
    required this.hasOver,
    required this.noMeal,
  });
  static const none = AllowanceCheck(
    meals: [],
    allowed: 0,
    actual: 0,
    over: 0,
    hasOver: false,
    noMeal: 0,
  );

  factory AllowanceCheck.fromJson(Map<String, dynamic> j) => AllowanceCheck(
    meals: [
      for (final m in (j['meals'] as List? ?? const []))
        MealAllowanceCheck.fromJson((m as Map).cast<String, dynamic>()),
    ],
    allowed: _d(j['allowed']),
    actual: _d(j['actual']),
    over: _d(j['over']),
    hasOver: j['hasOver'] == true,
    noMeal: _d(j['noMeal']),
  );
}

int _paise(double v) => (v * 100).round();
double _rupees(int paise) => paise / 100;

/// The TEAM's limit for one meal of one work, as the artist's form sees it before anything is typed:
/// heads × the allowance per head, and what the team has already logged for that meal on the work.
class TeamMealState {
  final String workId;

  /// The artist chose this work (rather than the app picking it by time).
  final bool pinned;

  /// Everyone assigned to the work (lead + assistants).
  final int heads;

  /// Null when no allowance is set for the meal. For several meals at once it is the SUM of their
  /// allowances per head (null if any of them has none).
  final double? allowancePerHead;
  final double? limit;
  final double alreadySpent;

  /// The meals this limit covers: the ones being entered, widened by any bill already filed that
  /// spans them (empty from an older server).
  final List<String> meals;

  const TeamMealState({
    required this.workId,
    required this.pinned,
    required this.heads,
    required this.allowancePerHead,
    required this.limit,
    required this.alreadySpent,
    this.meals = const [],
  });

  factory TeamMealState.fromJson(Map<String, dynamic> j) => TeamMealState(
    workId: '${j['workId'] ?? ''}',
    pinned: j['pinned'] == true,
    heads: (j['heads'] as num?)?.toInt() ?? 0,
    allowancePerHead: (j['allowancePerHead'] as num?)?.toDouble(),
    limit: (j['limit'] as num?)?.toDouble(),
    alreadySpent: _d(j['alreadySpent']),
    meals: _meals(j['meals']),
  );
}

/// What a meal can be filled in with, worked out from the team on the work: with N heads at ₹X each
/// the whole team's meal is N × ₹X; less what the team has already logged for it, that is what is
/// left. Null when there is nothing to work from (no allowance set for the meal, or nobody assigned).
class TeamAmount {
  final int heads;
  final double perHead;

  /// heads × the allowance per head.
  final double whole;
  final double alreadySpent;

  /// whole − alreadySpent, never below 0.
  final double left;

  const TeamAmount._({
    required this.heads,
    required this.perHead,
    required this.whole,
    required this.alreadySpent,
    required this.left,
  });

  static TeamAmount? of(TeamMealState? s) {
    if (s == null || s.allowancePerHead == null || s.heads <= 0) return null;
    final per = _paise(s.allowancePerHead!);
    final whole = per * s.heads;
    final spent = _paise(s.alreadySpent);
    final left = whole - spent;
    return TeamAmount._(
      heads: s.heads,
      perHead: _rupees(per),
      whole: _rupees(whole),
      alreadySpent: _rupees(spent),
      left: _rupees(left < 0 ? 0 : left),
    );
  }

  bool get someoneLogged => alreadySpent > 0;

  /// What the amount field starts with: the whole team's meal, or — once someone on the team has
  /// logged this meal — what is left of it. Null when nothing is left.
  double? get suggested => someoneLogged ? (left > 0 ? left : null) : whole;

  /// An amount as it is written in the field: whole rupees without decimals.
  static String fieldText(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

/// Is the team over its limit for the meal, counting an amount being entered? The same arithmetic as
/// the server (utils/foodAllowance.js teamMealCheck), so the warning can follow the typing without a
/// request per keystroke — and the server still reports the same answer when it is saved.
class TeamMealCheck {
  /// One meal, or the key of several ('breakfast+lunch+dinner').
  final String meal;
  final List<String> meals;
  final int heads;
  final double? allowancePerHead;
  final double? limit;
  final double alreadySpent;
  final double thisAmount;
  final double total;
  final double over;

  /// over | within | no_rule | no_heads
  final String status;

  const TeamMealCheck({
    required this.meal,
    this.meals = const [],
    required this.heads,
    required this.allowancePerHead,
    required this.limit,
    required this.alreadySpent,
    required this.thisAmount,
    required this.total,
    required this.over,
    required this.status,
  });

  bool get isOver => status == 'over';
  bool get isWithin => status == 'within';

  /// What is left of the limit (0 when over).
  double get left =>
      limit == null ? 0 : (limit! - total).clamp(0, double.infinity).toDouble();

  factory TeamMealCheck.fromJson(Map<String, dynamic> j) => TeamMealCheck(
    meal: '${j['meal'] ?? ''}',
    meals: _meals(j['meals']),
    heads: (j['heads'] as num?)?.toInt() ?? 0,
    allowancePerHead: (j['allowancePerHead'] as num?)?.toDouble(),
    limit: (j['limit'] as num?)?.toDouble(),
    alreadySpent: _d(j['alreadySpent']),
    thisAmount: _d(j['thisAmount']),
    total: _d(j['total']),
    over: _d(j['over']),
    status: '${j['status'] ?? ''}',
  );

  /// [amount] on top of what [state] says the team already logged.
  factory TeamMealCheck.compute(
    TeamMealState state,
    double amount, {
    String meal = '',
    List<String> meals = const [],
  }) {
    final spent = _paise(state.alreadySpent);
    final now = _paise(amount);
    TeamMealCheck build(String status, {double? limit, double over = 0}) =>
        TeamMealCheck(
          meal: meal,
          meals: meals,
          heads: state.heads,
          allowancePerHead: state.allowancePerHead,
          limit: limit,
          alreadySpent: _rupees(spent),
          thisAmount: _rupees(now),
          total: _rupees(spent + now),
          over: over,
          status: status,
        );
    if (state.allowancePerHead == null) return build('no_rule');
    if (state.heads <= 0) return build('no_heads');
    final limit = (_paise(state.allowancePerHead!) * state.heads);
    final over = (spent + now - limit).clamp(0, 1 << 40);
    return build(
      over > 0 ? 'over' : 'within',
      limit: _rupees(limit),
      over: _rupees(over),
    );
  }
}

/// On an expense Accounts reads: the team's total for that meal on the work against the limit.
class ExpenseLimit {
  /// One meal, or the key of several ('breakfast+lunch+dinner').
  final String meal;
  final List<String> meals;
  final int heads;
  final double allowancePerHead;
  final double limit;

  /// Everything the team logged for that meal on the work (this expense included).
  final double teamTotal;
  final double over;

  /// over | within
  final String status;

  const ExpenseLimit({
    required this.meal,
    this.meals = const [],
    required this.heads,
    required this.allowancePerHead,
    required this.limit,
    required this.teamTotal,
    required this.over,
    required this.status,
  });

  bool get isOver => status == 'over';

  factory ExpenseLimit.fromJson(Map<String, dynamic> j) => ExpenseLimit(
    meal: '${j['meal'] ?? ''}',
    meals: _meals(j['meals']),
    heads: (j['heads'] as num?)?.toInt() ?? 0,
    allowancePerHead: _d(j['allowancePerHead']),
    limit: _d(j['limit']),
    teamTotal: _d(j['teamTotal']),
    over: _d(j['over']),
    status: '${j['status'] ?? ''}',
  );
}

/// What the artist is told while adding a meal: the allowance per head, and the heads on the work.
class MealAllowanceHint {
  final double amountPerHead;

  /// Everyone assigned to the suggested work; 0 when there is none that day.
  final int heads;
  const MealAllowanceHint({required this.amountPerHead, required this.heads});

  /// heads × the allowance — what the whole team may spend on this meal.
  double get teamAllowance => amountPerHead * heads;

  factory MealAllowanceHint.fromJson(Map<String, dynamic> j) =>
      MealAllowanceHint(
        amountPerHead: _d(j['amountPerHead']),
        heads: (j['heads'] as num?)?.toInt() ?? 0,
      );
}
