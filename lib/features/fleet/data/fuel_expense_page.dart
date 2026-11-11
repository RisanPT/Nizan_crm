import 'package:flutter/foundation.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';

// The Accounts → Fleet Expenses list is filtered, sorted and paged ON THE SERVER, so
// every page and every total is right whatever the number of expenses. These are
// the request ([FuelExpenseQuery]) and the response ([FuelExpensePage]).

const _unset = Object();

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// What to show: the period, the filters, the sort and which page.
/// An immutable value: two equal queries are the same cached request.
@immutable
class FuelExpenseQuery {
  /// 'YYYY-MM-DD' (inclusive), or null = no limit on that side.
  final String? from;
  final String? to;

  /// pending | approved | rejected (empty = all)
  final Set<String> statuses;
  final Set<String> categories;
  final Set<String> paymentModes;
  final String? driverId;
  final String? vehicleId;

  /// 'with' | 'without' | null — has a bill photo or not.
  final String? bill;

  /// 'linked' | 'whole_day' | null — tied to one work, or filed under the whole day.
  final String? work;
  final double? minAmount;
  final double? maxAmount;
  final String search;

  /// date_desc | date_asc | amount_desc | amount_asc
  final String sort;
  final int page;
  final int limit;

  const FuelExpenseQuery({
    this.from,
    this.to,
    this.statuses = const {},
    this.categories = const {},
    this.paymentModes = const {},
    this.driverId,
    this.vehicleId,
    this.bill,
    this.work,
    this.minAmount,
    this.maxAmount,
    this.search = '',
    this.sort = 'date_desc',
    this.page = 1,
    this.limit = 20,
  });

  /// The whole of one calendar month.
  static (String, String) monthBounds(DateTime anyDayInMonth) {
    final first = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final last = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 0);
    return (_day(first), _day(last));
  }

  FuelExpenseQuery copyWith({
    Object? from = _unset,
    Object? to = _unset,
    Set<String>? statuses,
    Set<String>? categories,
    Set<String>? paymentModes,
    Object? driverId = _unset,
    Object? vehicleId = _unset,
    Object? bill = _unset,
    Object? work = _unset,
    Object? minAmount = _unset,
    Object? maxAmount = _unset,
    String? search,
    String? sort,
    int? page,
    int? limit,
  }) {
    return FuelExpenseQuery(
      from: identical(from, _unset) ? this.from : from as String?,
      to: identical(to, _unset) ? this.to : to as String?,
      statuses: statuses ?? this.statuses,
      categories: categories ?? this.categories,
      paymentModes: paymentModes ?? this.paymentModes,
      driverId: identical(driverId, _unset) ? this.driverId : driverId as String?,
      vehicleId: identical(vehicleId, _unset) ? this.vehicleId : vehicleId as String?,
      bill: identical(bill, _unset) ? this.bill : bill as String?,
      work: identical(work, _unset) ? this.work : work as String?,
      // any number: a whole-number literal is an int, which `as double?` would refuse
      minAmount: identical(minAmount, _unset) ? this.minAmount : (minAmount as num?)?.toDouble(),
      maxAmount: identical(maxAmount, _unset) ? this.maxAmount : (maxAmount as num?)?.toDouble(),
      search: search ?? this.search,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  /// A change of filter always goes back to the first page.
  FuelExpenseQuery refiltered({
    Object? from = _unset,
    Object? to = _unset,
    Set<String>? statuses,
    Set<String>? categories,
    Set<String>? paymentModes,
    Object? driverId = _unset,
    Object? vehicleId = _unset,
    Object? bill = _unset,
    Object? work = _unset,
    Object? minAmount = _unset,
    Object? maxAmount = _unset,
    String? search,
    String? sort,
    int? limit,
  }) =>
      copyWith(
        from: from,
        to: to,
        statuses: statuses,
        categories: categories,
        paymentModes: paymentModes,
        driverId: driverId,
        vehicleId: vehicleId,
        bill: bill,
        work: work,
        minAmount: minAmount,
        maxAmount: maxAmount,
        search: search,
        sort: sort,
        limit: limit,
        page: 1,
      );

  /// How many of the filters in the "Filters" panel are on (the period, status,
  /// search and sort are in the bar, so they don't count).
  int get advancedCount =>
      (driverId != null ? 1 : 0) +
      (vehicleId != null ? 1 : 0) +
      (categories.isNotEmpty ? 1 : 0) +
      (paymentModes.isNotEmpty ? 1 : 0) +
      (bill != null ? 1 : 0) +
      (work != null ? 1 : 0) +
      (minAmount != null || maxAmount != null ? 1 : 0);

  /// The request parameters. [paged] adds page / limit (+ the whole-set summary);
  /// [export] asks for every match instead; either way each expense comes with its
  /// day's works and km check (Accounts).
  Map<String, String> toParams({bool paged = true, bool export = false}) {
    String join(Set<String> s) => (s.toList()..sort()).join(',');
    return {
      'from': ?from,
      'to': ?to,
      if (statuses.isNotEmpty) 'status': join(statuses),
      if (categories.isNotEmpty) 'category': join(categories),
      if (paymentModes.isNotEmpty) 'paymentMode': join(paymentModes),
      'driverId': ?driverId,
      'vehicleId': ?vehicleId,
      'bill': ?bill,
      'work': ?work,
      if (minAmount != null) 'minAmount': '$minAmount',
      if (maxAmount != null) 'maxAmount': '$maxAmount',
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'sort': sort,
      'withWorks': '1',
      if (export) 'export': '1',
      if (paged && !export) ...{'page': '$page', 'limit': '$limit', 'summary': '1'},
    };
  }

  @override
  bool operator ==(Object other) =>
      other is FuelExpenseQuery &&
      other.from == from &&
      other.to == to &&
      setEquals(other.statuses, statuses) &&
      setEquals(other.categories, categories) &&
      setEquals(other.paymentModes, paymentModes) &&
      other.driverId == driverId &&
      other.vehicleId == vehicleId &&
      other.bill == bill &&
      other.work == work &&
      other.minAmount == minAmount &&
      other.maxAmount == maxAmount &&
      other.search == search &&
      other.sort == sort &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(
        from,
        to,
        Object.hashAllUnordered(statuses),
        Object.hashAllUnordered(categories),
        Object.hashAllUnordered(paymentModes),
        driverId,
        vehicleId,
        bill,
        work,
        minAmount,
        maxAmount,
        search,
        sort,
        page,
        limit,
      );
}

double _num0(Object? v) => (v as num?)?.toDouble() ?? 0;

class StatusTotal {
  final int count;
  final double amount;
  const StatusTotal(this.count, this.amount);

  factory StatusTotal.fromJson(Object? j) => j is Map
      ? StatusTotal((j['count'] as num?)?.toInt() ?? 0, _num0(j['amount']))
      : const StatusTotal(0, 0);
}

class CategoryTotal {
  final String category;
  final int count;
  final double amount;
  const CategoryTotal(this.category, this.count, this.amount);
}

class DriverTotal {
  final String driverId;
  final String name;
  final int count;
  final double amount;
  const DriverTotal(this.driverId, this.name, this.count, this.amount);
}

/// Totals for the WHOLE filtered set (every page), from the server.
class ExpenseSummary {
  /// Per status, ignoring the status filter — so the chips and cards stay comparable.
  final Map<String, StatusTotal> byStatus;

  /// Count and amount of exactly what the list shows (every page).
  final int shownCount;
  final double shownAmount;
  final List<CategoryTotal> byCategory;
  final List<DriverTotal> byDriver;

  const ExpenseSummary({
    required this.byStatus,
    required this.shownCount,
    required this.shownAmount,
    required this.byCategory,
    required this.byDriver,
  });

  StatusTotal status(String s) => byStatus[s] ?? const StatusTotal(0, 0);
  int get allCount => byStatus.values.fold(0, (a, s) => a + s.count);
  double get allAmount => byStatus.values.fold(0.0, (a, s) => a + s.amount);

  factory ExpenseSummary.fromJson(Map<String, dynamic> j) {
    final st = (j['byStatus'] as Map?) ?? const {};
    final shown = (j['shown'] as Map?) ?? const {};
    return ExpenseSummary(
      byStatus: {for (final e in st.entries) '${e.key}': StatusTotal.fromJson(e.value)},
      shownCount: (shown['count'] as num?)?.toInt() ?? 0,
      shownAmount: _num0(shown['amount']),
      byCategory: [
        for (final c in (j['byCategory'] as List? ?? const []))
          CategoryTotal('${(c as Map)['category']}', (c['count'] as num?)?.toInt() ?? 0, _num0(c['amount'])),
      ],
      byDriver: [
        for (final d in (j['byDriver'] as List? ?? const []))
          DriverTotal('${(d as Map)['driverId']}', '${d['name'] ?? 'Driver'}', (d['count'] as num?)?.toInt() ?? 0, _num0(d['amount'])),
      ],
    );
  }
}

class FuelExpensePage {
  final List<FuelExpense> items;
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
  final ExpenseSummary? summary;

  const FuelExpensePage({
    required this.items,
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.summary,
  });

  factory FuelExpensePage.fromJson(Map<String, dynamic> j) {
    final s = j['summary'];
    return FuelExpensePage(
      items: [for (final e in (j['items'] as List? ?? const [])) FuelExpense.fromJson((e as Map).cast<String, dynamic>())],
      page: (j['page'] as num?)?.toInt() ?? 1,
      limit: (j['limit'] as num?)?.toInt() ?? 20,
      totalItems: (j['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (j['totalPages'] as num?)?.toInt() ?? 1,
      summary: s is Map ? ExpenseSummary.fromJson(s.cast<String, dynamic>()) : null,
    );
  }
}

/// Every expense matching a query, for the export (the server caps it).
class FuelExpenseExport {
  final List<FuelExpense> items;
  final int totalItems;

  /// There were more than the cap, so [items] is only the first part.
  final bool truncated;
  const FuelExpenseExport(this.items, this.totalItems, this.truncated);
}
