import 'package:flutter/foundation.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense_page.dart' show StatusTotal;

// Accounts lists of artist COLLECTIONS and artist EXPENSES (Artist Finance, Finance &
// Invoices) are filtered, sorted and paged ON THE SERVER, so every page and every
// total is right whatever the number of entries. These are the request
// ([FinanceQuery]) and the response ([FinancePage]).

const _unset = Object();

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// What to show: the period, the filters, the sort and which page. An immutable
/// value: two equal queries are the same cached request. One class serves both
/// lists; the server ignores the filters that don't apply to a kind.
@immutable
class FinanceQuery {
  /// 'YYYY-MM-DD' (inclusive), or null = no limit on that side.
  final String? from;
  final String? to;

  /// pending | verified | rejected (empty = all)
  final Set<String> statuses;

  /// The artist.
  final String? employeeId;

  /// Collections: cash | upi | bank_transfer | other.
  final Set<String> paymentModes;

  /// Expenses: food | travel | stay | materials | fuel | other.
  final Set<String> categories;

  /// Expenses: bridal | model_shoot.
  final String? workType;

  /// 'with' | 'without' — has a screenshot / receipt photo or not.
  final String? bill;

  /// Collections: booking | trial | none. Expenses: booking | none.
  final String? link;

  /// The screenshot check: match | mismatch | skipped | pending.
  final Set<String> ocr;
  final double? minAmount;
  final double? maxAmount;
  final String search;

  /// date_desc | date_asc | amount_desc | amount_asc
  final String sort;
  final int page;
  final int limit;

  /// Expenses: also send, for each food expense, the work it was eaten for (the Accounts view).
  final bool withWorks;

  const FinanceQuery({
    this.from,
    this.to,
    this.statuses = const {},
    this.employeeId,
    this.paymentModes = const {},
    this.categories = const {},
    this.workType,
    this.bill,
    this.link,
    this.ocr = const {},
    this.minAmount,
    this.maxAmount,
    this.search = '',
    this.sort = 'date_desc',
    this.page = 1,
    this.limit = 20,
    this.withWorks = false,
  });

  /// The whole of one calendar month.
  static (String, String) monthBounds(DateTime anyDayInMonth) {
    final first = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final last = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 0);
    return (_day(first), _day(last));
  }

  FinanceQuery copyWith({
    Object? from = _unset,
    Object? to = _unset,
    Set<String>? statuses,
    Object? employeeId = _unset,
    Set<String>? paymentModes,
    Set<String>? categories,
    Object? workType = _unset,
    Object? bill = _unset,
    Object? link = _unset,
    Set<String>? ocr,
    Object? minAmount = _unset,
    Object? maxAmount = _unset,
    String? search,
    String? sort,
    int? page,
    int? limit,
    bool? withWorks,
  }) {
    return FinanceQuery(
      from: identical(from, _unset) ? this.from : from as String?,
      to: identical(to, _unset) ? this.to : to as String?,
      statuses: statuses ?? this.statuses,
      employeeId: identical(employeeId, _unset) ? this.employeeId : employeeId as String?,
      paymentModes: paymentModes ?? this.paymentModes,
      categories: categories ?? this.categories,
      workType: identical(workType, _unset) ? this.workType : workType as String?,
      bill: identical(bill, _unset) ? this.bill : bill as String?,
      link: identical(link, _unset) ? this.link : link as String?,
      ocr: ocr ?? this.ocr,
      // any number: a whole-number literal is an int, which `as double?` would refuse
      minAmount: identical(minAmount, _unset) ? this.minAmount : (minAmount as num?)?.toDouble(),
      maxAmount: identical(maxAmount, _unset) ? this.maxAmount : (maxAmount as num?)?.toDouble(),
      search: search ?? this.search,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      withWorks: withWorks ?? this.withWorks,
    );
  }

  /// A change of filter always goes back to the first page.
  FinanceQuery refiltered({
    Object? from = _unset,
    Object? to = _unset,
    Set<String>? statuses,
    Object? employeeId = _unset,
    Set<String>? paymentModes,
    Set<String>? categories,
    Object? workType = _unset,
    Object? bill = _unset,
    Object? link = _unset,
    Set<String>? ocr,
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
        employeeId: employeeId,
        paymentModes: paymentModes,
        categories: categories,
        workType: workType,
        bill: bill,
        link: link,
        ocr: ocr,
        minAmount: minAmount,
        maxAmount: maxAmount,
        search: search,
        sort: sort,
        limit: limit,
        page: 1,
      );

  /// How many of the filters in the "Filters" form are on (the period, status,
  /// search and sort live in the bar, so they don't count).
  int get advancedCount =>
      (employeeId != null ? 1 : 0) +
      (paymentModes.isNotEmpty ? 1 : 0) +
      (categories.isNotEmpty ? 1 : 0) +
      (workType != null ? 1 : 0) +
      (bill != null ? 1 : 0) +
      (link != null ? 1 : 0) +
      (ocr.isNotEmpty ? 1 : 0) +
      (minAmount != null || maxAmount != null ? 1 : 0);

  /// Anything switched on besides the period.
  bool get isFiltered => advancedCount > 0 || search.trim().isNotEmpty || statuses.isNotEmpty;

  /// The request parameters. [export] asks for every match instead of a page.
  Map<String, String> toParams({bool export = false}) {
    String join(Set<String> s) => (s.toList()..sort()).join(',');
    return {
      'from': ?from,
      'to': ?to,
      if (statuses.isNotEmpty) 'status': join(statuses),
      'employeeId': ?employeeId,
      if (paymentModes.isNotEmpty) 'paymentMode': join(paymentModes),
      if (categories.isNotEmpty) 'category': join(categories),
      'workType': ?workType,
      'bill': ?bill,
      'link': ?link,
      if (ocr.isNotEmpty) 'ocr': join(ocr),
      if (minAmount != null) 'minAmount': '$minAmount',
      if (maxAmount != null) 'maxAmount': '$maxAmount',
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'sort': sort,
      if (withWorks) 'withWorks': '1',
      if (export) 'export': '1' else ...{'page': '$page', 'limit': '$limit', 'summary': '1'},
    };
  }

  @override
  bool operator ==(Object other) =>
      other is FinanceQuery &&
      other.from == from &&
      other.to == to &&
      setEquals(other.statuses, statuses) &&
      other.employeeId == employeeId &&
      setEquals(other.paymentModes, paymentModes) &&
      setEquals(other.categories, categories) &&
      other.workType == workType &&
      other.bill == bill &&
      other.link == link &&
      setEquals(other.ocr, ocr) &&
      other.minAmount == minAmount &&
      other.maxAmount == maxAmount &&
      other.search == search &&
      other.sort == sort &&
      other.page == page &&
      other.limit == limit &&
      other.withWorks == withWorks;

  @override
  int get hashCode => Object.hash(
        from,
        to,
        Object.hashAllUnordered(statuses),
        employeeId,
        Object.hashAllUnordered(paymentModes),
        Object.hashAllUnordered(categories),
        workType,
        bill,
        link,
        Object.hashAllUnordered(ocr),
        minAmount,
        maxAmount,
        search,
        sort,
        Object.hash(page, limit, withWorks),
      );
}

double _num0(Object? v) => (v as num?)?.toDouble() ?? 0;

/// One row of a breakdown: a payment mode / category / work type, or an artist.
class LabelTotal {
  /// The key (payment mode, category, work type) or the artist's id.
  final String key;

  /// What to show: the key's label, or the artist's name.
  final String name;
  final int count;
  final double amount;
  const LabelTotal(this.key, this.name, this.count, this.amount);
}

/// Totals for the WHOLE filtered set (every page), from the server.
class FinanceSummary {
  /// pending / verified / rejected, ignoring the status filter — so the chips and
  /// cards stay comparable.
  final Map<String, StatusTotal> byStatus;

  /// Count and amount of exactly what the list shows (every page).
  final int shownCount;
  final double shownAmount;

  /// Collections: per payment mode.
  final List<LabelTotal> byMode;

  /// Expenses: per category and per work type.
  final List<LabelTotal> byCategory;
  final List<LabelTotal> byWorkType;

  /// Top artists by amount.
  final List<LabelTotal> byArtist;

  const FinanceSummary({
    required this.byStatus,
    required this.shownCount,
    required this.shownAmount,
    required this.byMode,
    required this.byCategory,
    required this.byWorkType,
    required this.byArtist,
  });

  StatusTotal status(String s) => byStatus[s] ?? const StatusTotal(0, 0);
  int get allCount => byStatus.values.fold(0, (a, s) => a + s.count);
  double get allAmount => byStatus.values.fold(0.0, (a, s) => a + s.amount);

  factory FinanceSummary.fromJson(Map<String, dynamic> j) {
    List<LabelTotal> rows(String key, String field) => [
          for (final r in (j[key] as List? ?? const []))
            LabelTotal('${(r as Map)[field]}', '${r[field]}', (r['count'] as num?)?.toInt() ?? 0, _num0(r['amount'])),
        ];
    final st = (j['byStatus'] as Map?) ?? const {};
    final shown = (j['shown'] as Map?) ?? const {};
    return FinanceSummary(
      byStatus: {for (final e in st.entries) '${e.key}': StatusTotal.fromJson(e.value)},
      shownCount: (shown['count'] as num?)?.toInt() ?? 0,
      shownAmount: _num0(shown['amount']),
      byMode: rows('byMode', 'mode'),
      byCategory: rows('byCategory', 'category'),
      byWorkType: rows('byWorkType', 'workType'),
      byArtist: [
        for (final r in (j['byArtist'] as List? ?? const []))
          LabelTotal('${(r as Map)['employeeId']}', '${r['name'] ?? 'Artist'}', (r['count'] as num?)?.toInt() ?? 0, _num0(r['amount'])),
      ],
    );
  }
}

class FinancePage<T> {
  final List<T> items;
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
  final FinanceSummary? summary;

  const FinancePage({
    required this.items,
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.summary,
  });

  factory FinancePage.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) parse) {
    final s = j['summary'];
    return FinancePage(
      items: [for (final e in (j['items'] as List? ?? const [])) parse((e as Map).cast<String, dynamic>())],
      page: (j['page'] as num?)?.toInt() ?? 1,
      limit: (j['limit'] as num?)?.toInt() ?? 20,
      totalItems: (j['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (j['totalPages'] as num?)?.toInt() ?? 1,
      summary: s is Map ? FinanceSummary.fromJson(s.cast<String, dynamic>()) : null,
    );
  }
}

/// Every entry matching a query, for the export (the server caps it).
class FinanceExport<T> {
  final List<T> items;
  final int totalItems;

  /// There were more than the cap, so [items] is only the first part.
  final bool truncated;
  const FinanceExport(this.items, this.totalItems, this.truncated);

  factory FinanceExport.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) parse) => FinanceExport(
        [for (final e in (j['items'] as List? ?? const [])) parse((e as Map).cast<String, dynamic>())],
        (j['totalItems'] as num?)?.toInt() ?? 0,
        j['truncated'] == true,
      );
}
