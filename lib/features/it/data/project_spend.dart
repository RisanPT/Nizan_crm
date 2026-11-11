import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';

// What a project has SPENT against the cost its finance head approved, as the server works it out (backend
// utils/projectSpend.js): approved expenses are "spent", pending ones "committed", a rejected one is nothing.

/// One slice of the spending (by expense head, department or month): [key] is the head code, the department's name or "2026-11".
class SpendBucket {
  final String key;
  final double spent;
  final double committed;
  const SpendBucket({required this.key, this.spent = 0, this.committed = 0});

  double get total => spent + committed;

  factory SpendBucket.fromJson(Map<String, dynamic> j) => SpendBucket(
    key: (j['key'] ?? '').toString(),
    spent: (j['spent'] as num?)?.toDouble() ?? 0,
    committed: (j['committed'] as num?)?.toDouble() ?? 0,
  );
}

/// One expense charged to the project, as its page lists it.
class ProjectSpendExpense {
  final String id;
  final String title;
  final double amount;
  final DateTime? date;
  final String status; // approved | pending | rejected
  final String department;
  final String expenseHead;
  final String filedByName;
  final String overBudgetReason;
  const ProjectSpendExpense({
    required this.id,
    required this.title,
    required this.amount,
    this.date,
    this.status = 'pending',
    this.department = '',
    this.expenseHead = '',
    this.filedByName = '',
    this.overBudgetReason = '',
  });

  factory ProjectSpendExpense.fromJson(Map<String, dynamic> j) => ProjectSpendExpense(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
    status: (j['status'] ?? 'pending').toString(),
    department: (j['department'] ?? '').toString(),
    expenseHead: (j['expenseHead'] ?? '').toString(),
    filedByName: (j['filedByName'] ?? '').toString(),
    overBudgetReason: (j['overBudgetReason'] ?? '').toString(),
  );
}

/// How far spending has got along the approved limit: none (nothing approved yet) | ok | warn (from 80%) | over.
bool isOverLevel(String level) => level == 'over';

class ProjectSpend {
  final double limit;
  final double requested;
  final double spent;
  final double committed;
  final double used;

  /// What is left of the limit; negative once over it.
  final double available;
  final int? usedPercent;
  final String level;
  final List<SpendBucket> byHead;
  final List<SpendBucket> byDepartment;
  final List<SpendBucket> byMonth;
  final List<ProjectSpendExpense> expenses;

  const ProjectSpend({
    this.limit = 0,
    this.requested = 0,
    this.spent = 0,
    this.committed = 0,
    this.used = 0,
    this.available = 0,
    this.usedPercent,
    this.level = 'none',
    this.byHead = const [],
    this.byDepartment = const [],
    this.byMonth = const [],
    this.expenses = const [],
  });

  bool get isOver => level == 'over';

  factory ProjectSpend.fromJson(Map<String, dynamic> j) {
    List<SpendBucket> buckets(dynamic v) => [
      for (final e in (v as List?) ?? const [])
        if (e is Map) SpendBucket.fromJson(e.cast<String, dynamic>()),
    ];
    double n(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return ProjectSpend(
      limit: n(j['limit']),
      requested: n(j['requested']),
      spent: n(j['spent']),
      committed: n(j['committed']),
      used: n(j['used']),
      available: n(j['available']),
      usedPercent: (j['usedPercent'] as num?)?.toInt(),
      level: (j['level'] ?? 'none').toString(),
      byHead: buckets(j['byHead']),
      byDepartment: buckets(j['byDepartment']),
      byMonth: buckets(j['byMonth']),
      expenses: [
        for (final e in (j['expenses'] as List?) ?? const [])
          if (e is Map) ProjectSpendExpense.fromJson(e.cast<String, dynamic>()),
      ],
    );
  }
}

/// A project an expense can be charged to (its cost is approved). The amounts come only for those who may see money.
class ChargeableProject {
  final String id;
  final String name;
  final String department;
  final String status;
  final String level;
  final double? limit;
  final double? used;
  final double? available;
  const ChargeableProject({
    required this.id,
    required this.name,
    this.department = '',
    this.status = '',
    this.level = 'ok',
    this.limit,
    this.used,
    this.available,
  });

  bool get hasAmounts => limit != null;

  factory ChargeableProject.fromJson(Map<String, dynamic> j) => ChargeableProject(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    department: (j['department'] ?? '').toString(),
    status: (j['status'] ?? '').toString(),
    level: (j['level'] ?? 'ok').toString(),
    limit: (j['limit'] as num?)?.toDouble(),
    used: (j['used'] as num?)?.toDouble(),
    available: (j['available'] as num?)?.toDouble(),
  );
}

/// The server refused an expense charged to a project because it would take the project past its approved budget
/// (409 OVER_BUDGET: only the finance head can approve that; 409 OVER_BUDGET_REASON: the finance head must say why).
class OverBudgetRefusal {
  final String code;
  final String message;
  final double limit;
  final double used;
  final double after;
  const OverBudgetRefusal({required this.code, required this.message, this.limit = 0, this.used = 0, this.after = 0});

  /// The finance head may go ahead — with a reason.
  bool get needsReason => code == 'OVER_BUDGET_REASON';

  /// The refusal inside [error], or null when it is some other failure.
  static OverBudgetRefusal? of(Object? error) {
    final cause = error is AppException ? error.cause : error;
    if (cause is! DioException || cause.response?.statusCode != 409) return null;
    final data = cause.response?.data;
    if (data is! Map) return null;
    final code = '${data['code'] ?? ''}';
    if (code != 'OVER_BUDGET' && code != 'OVER_BUDGET_REASON') return null;
    double n(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return OverBudgetRefusal(
      code: code,
      message: '${data['message'] ?? ''}',
      limit: n(data['limit']),
      used: n(data['used']),
      after: n(data['after']),
    );
  }
}
