import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/providers/dio_provider.dart';

// ── Models ───────────────────────────────────────────────────────────────────
class NpsPoint {
  final String month;
  final int nps, responses;
  const NpsPoint({required this.month, this.nps = 0, this.responses = 0});
  factory NpsPoint.fromJson(Map<String, dynamic> j) => NpsPoint(
        month: (j['month'] ?? '').toString(),
        nps: (j['nps'] as num?)?.toInt() ?? 0,
        responses: (j['responses'] as num?)?.toInt() ?? 0,
      );
}

class NpsSummary {
  final int nps, promoters, passives, detractors, responses;
  final List<NpsPoint> trend;
  const NpsSummary({
    this.nps = 0,
    this.promoters = 0,
    this.passives = 0,
    this.detractors = 0,
    this.responses = 0,
    this.trend = const [],
  });
  factory NpsSummary.fromJson(Map<String, dynamic> j) => NpsSummary(
        nps: (j['nps'] as num?)?.toInt() ?? 0,
        promoters: (j['promoters'] as num?)?.toInt() ?? 0,
        passives: (j['passives'] as num?)?.toInt() ?? 0,
        detractors: (j['detractors'] as num?)?.toInt() ?? 0,
        responses: (j['responses'] as num?)?.toInt() ?? 0,
        trend: ((j['trend'] as List?) ?? const [])
            .map((e) => NpsPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SlotMonth {
  final String month;
  final int capacity, booked, pct;
  const SlotMonth(
      {required this.month, this.capacity = 0, this.booked = 0, this.pct = 0});
  factory SlotMonth.fromJson(Map<String, dynamic> j) => SlotMonth(
        month: (j['month'] ?? '').toString(),
        capacity: (j['capacity'] as num?)?.toInt() ?? 0,
        booked: (j['booked'] as num?)?.toInt() ?? 0,
        pct: (j['pct'] as num?)?.toInt() ?? 0,
      );
}

class SlotUtil {
  final String? fyLabel;
  final int totalCapacity, totalBooked, pct;
  final List<SlotMonth> byMonth;
  const SlotUtil({
    this.fyLabel,
    this.totalCapacity = 0,
    this.totalBooked = 0,
    this.pct = 0,
    this.byMonth = const [],
  });
  factory SlotUtil.fromJson(Map<String, dynamic> j) => SlotUtil(
        fyLabel: j['fyLabel'] as String?,
        totalCapacity: (j['totalCapacity'] as num?)?.toInt() ?? 0,
        totalBooked: (j['totalBooked'] as num?)?.toInt() ?? 0,
        pct: (j['pct'] as num?)?.toInt() ?? 0,
        byMonth: ((j['byMonth'] as List?) ?? const [])
            .map((e) => SlotMonth.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SegmentRow {
  final String name;
  final int bookings;
  final double revenue;
  const SegmentRow({required this.name, this.bookings = 0, this.revenue = 0});
  factory SegmentRow.fromJson(Map<String, dynamic> j) => SegmentRow(
        name: (j['name'] ?? '').toString(),
        bookings: (j['bookings'] as num?)?.toInt() ?? 0,
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
      );
}

/// One row of the data-quality worklist: a booking missing one or more of the
/// three analytics dimensions (event date / culture / location).
class CoverageItem {
  final String id, customerName;
  final DateTime? bookingDate;
  final List<String> missing;
  const CoverageItem({
    this.id = '',
    this.customerName = '',
    this.bookingDate,
    this.missing = const [],
  });
  factory CoverageItem.fromJson(Map<String, dynamic> j) => CoverageItem(
        id: (j['_id'] ?? '').toString(),
        customerName: (j['customerName'] ?? '').toString(),
        bookingDate: j['bookingDate'] != null
            ? DateTime.tryParse(j['bookingDate'].toString())
            : null,
        missing: ((j['missing'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Completeness of the three analytics dimensions across ALL bookings — powers
/// the "find the proper event dates (and culture/location) in existing data"
/// data-quality panel.
class Coverage {
  final int eventTotal, eventWithDate, eventMissing;
  final int cultureExplicit, cultureInferred, cultureUnknown;
  final int locWithRegion, locWithDistrict, locWithPincode, locNone;
  final List<CoverageItem> worklist;
  const Coverage({
    this.eventTotal = 0,
    this.eventWithDate = 0,
    this.eventMissing = 0,
    this.cultureExplicit = 0,
    this.cultureInferred = 0,
    this.cultureUnknown = 0,
    this.locWithRegion = 0,
    this.locWithDistrict = 0,
    this.locWithPincode = 0,
    this.locNone = 0,
    this.worklist = const [],
  });
  factory Coverage.fromJson(Map<String, dynamic> j) {
    final ed = (j['eventDate'] as Map<String, dynamic>?) ?? const {};
    final cu = (j['culture'] as Map<String, dynamic>?) ?? const {};
    final lo = (j['location'] as Map<String, dynamic>?) ?? const {};
    int n(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;
    return Coverage(
      eventTotal: n(ed, 'total'),
      eventWithDate: n(ed, 'withDate'),
      eventMissing: n(ed, 'missing'),
      cultureExplicit: n(cu, 'explicit'),
      cultureInferred: n(cu, 'inferred'),
      cultureUnknown: n(cu, 'unknown'),
      locWithRegion: n(lo, 'withRegion'),
      locWithDistrict: n(lo, 'withDistrict'),
      locWithPincode: n(lo, 'withPincode'),
      locNone: n(lo, 'none'),
      worklist: ((j['worklist'] as List?) ?? const [])
          .map((e) => CoverageItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MarketingInsights {
  final NpsSummary nps;
  final double avgBrideScore, avgTeamScore;
  final int csatSubmitted;
  final int artistUtilPct, artistBusy, artistTotal;
  final SlotUtil slot;
  final List<SegmentRow> byRegion, byDistrict, byPincode, byMonth, byCulture;
  final int totalBookings;
  final Coverage coverage;

  const MarketingInsights({
    this.nps = const NpsSummary(),
    this.avgBrideScore = 0,
    this.avgTeamScore = 0,
    this.csatSubmitted = 0,
    this.artistUtilPct = 0,
    this.artistBusy = 0,
    this.artistTotal = 0,
    this.slot = const SlotUtil(),
    this.byRegion = const [],
    this.byDistrict = const [],
    this.byPincode = const [],
    this.byMonth = const [],
    this.byCulture = const [],
    this.totalBookings = 0,
    this.coverage = const Coverage(),
  });

  factory MarketingInsights.fromJson(Map<String, dynamic> j) {
    final csat = (j['csat'] as Map<String, dynamic>?) ?? const {};
    final au = (j['artistUtilization'] as Map<String, dynamic>?) ?? const {};
    final seg = (j['segments'] as Map<String, dynamic>?) ?? const {};
    List<SegmentRow> rows(String k) => ((seg[k] as List?) ?? const [])
        .map((e) => SegmentRow.fromJson(e as Map<String, dynamic>))
        .toList();
    return MarketingInsights(
      nps: NpsSummary.fromJson((j['nps'] as Map<String, dynamic>?) ?? const {}),
      avgBrideScore: (csat['avgBrideScore'] as num?)?.toDouble() ?? 0,
      avgTeamScore: (csat['avgTeamScore'] as num?)?.toDouble() ?? 0,
      csatSubmitted: (csat['submitted'] as num?)?.toInt() ?? 0,
      artistUtilPct: (au['pct'] as num?)?.toInt() ?? 0,
      artistBusy: (au['busy'] as num?)?.toInt() ?? 0,
      artistTotal: (au['total'] as num?)?.toInt() ?? 0,
      slot: SlotUtil.fromJson((j['slotUtilization'] as Map<String, dynamic>?) ?? const {}),
      byRegion: rows('byRegion'),
      byDistrict: rows('byDistrict'),
      byPincode: rows('byPincode'),
      byMonth: rows('byMonth'),
      byCulture: rows('byCulture'),
      totalBookings: (seg['totalBookings'] as num?)?.toInt() ?? 0,
      coverage: Coverage.fromJson((j['coverage'] as Map<String, dynamic>?) ?? const {}),
    );
  }
}

// ── Year-over-year calendar ──────────────────────────────────────────────────
/// Bookings + revenue for a single day.
class DayStat {
  final int bookings;
  final double revenue;
  const DayStat({this.bookings = 0, this.revenue = 0});
  factory DayStat.fromJson(Map<String, dynamic> j) => DayStat(
        bookings: (j['bookings'] as num?)?.toInt() ?? 0,
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
      );
  bool get isEmpty => bookings == 0 && revenue == 0;
}

/// One month's this-year-vs-last-year totals (12 rows, Jan→Dec).
class MonthYoY {
  final int month; // 1-12
  final int curBookings, prevBookings;
  final double curRevenue, prevRevenue;
  const MonthYoY({
    required this.month,
    this.curBookings = 0,
    this.prevBookings = 0,
    this.curRevenue = 0,
    this.prevRevenue = 0,
  });
  factory MonthYoY.fromJson(Map<String, dynamic> j) => MonthYoY(
        month: (j['month'] as num?)?.toInt() ?? 0,
        curBookings: (j['curBookings'] as num?)?.toInt() ?? 0,
        prevBookings: (j['prevBookings'] as num?)?.toInt() ?? 0,
        curRevenue: (j['curRevenue'] as num?)?.toDouble() ?? 0,
        prevRevenue: (j['prevRevenue'] as num?)?.toDouble() ?? 0,
      );
}

/// Per-day booking counts + revenue for a calendar year and the previous year,
/// powering the marketing team's YoY comparison calendar. `current`/`previous`
/// are keyed by 'YYYY-MM-DD'.
class CalendarComparison {
  final int year, prevYear;
  final Map<String, DayStat> current, previous;
  final int curTotalBookings, prevTotalBookings;
  final double curTotalRevenue, prevTotalRevenue;
  final List<MonthYoY> byMonth;

  const CalendarComparison({
    this.year = 0,
    this.prevYear = 0,
    this.current = const {},
    this.previous = const {},
    this.curTotalBookings = 0,
    this.prevTotalBookings = 0,
    this.curTotalRevenue = 0,
    this.prevTotalRevenue = 0,
    this.byMonth = const [],
  });

  static String _key(int y, int m, int d) =>
      '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

  /// This year's stats for [date].
  DayStat curFor(DateTime date) =>
      current[_key(date.year, date.month, date.day)] ?? const DayStat();

  /// Last year's stats for the SAME month/day as [date] (the "exact date one
  /// year ago" the hover compares against).
  DayStat prevSameDay(DateTime date) =>
      previous[_key(date.year - 1, date.month, date.day)] ?? const DayStat();

  factory CalendarComparison.fromJson(Map<String, dynamic> j) {
    Map<String, DayStat> parseMap(dynamic v) {
      final out = <String, DayStat>{};
      if (v is Map) {
        v.forEach((k, val) {
          if (val is Map) {
            out[k.toString()] =
                DayStat.fromJson(val.cast<String, dynamic>());
          }
        });
      }
      return out;
    }

    final sum = (j['summary'] as Map<String, dynamic>?) ?? const {};
    final curSum = (sum['current'] as Map<String, dynamic>?) ?? const {};
    final prevSum = (sum['previous'] as Map<String, dynamic>?) ?? const {};
    return CalendarComparison(
      year: (j['year'] as num?)?.toInt() ?? 0,
      prevYear: (j['prevYear'] as num?)?.toInt() ?? 0,
      current: parseMap(j['current']),
      previous: parseMap(j['previous']),
      curTotalBookings: (curSum['bookings'] as num?)?.toInt() ?? 0,
      prevTotalBookings: (prevSum['bookings'] as num?)?.toInt() ?? 0,
      curTotalRevenue: (curSum['revenue'] as num?)?.toDouble() ?? 0,
      prevTotalRevenue: (prevSum['revenue'] as num?)?.toDouble() ?? 0,
      byMonth: ((sum['byMonth'] as List?) ?? const [])
          .map((e) => MonthYoY.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReEngagementClient {
  final String customerName, phone, service;
  final DateTime? lastEventDate;
  final int monthsSince, bookings;
  const ReEngagementClient({
    this.customerName = '',
    this.phone = '',
    this.service = '',
    this.lastEventDate,
    this.monthsSince = 0,
    this.bookings = 0,
  });
  factory ReEngagementClient.fromJson(Map<String, dynamic> j) => ReEngagementClient(
        customerName: (j['customerName'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        service: (j['service'] ?? '').toString(),
        lastEventDate: j['lastEventDate'] != null
            ? DateTime.tryParse(j['lastEventDate'].toString())
            : null,
        monthsSince: (j['monthsSince'] as num?)?.toInt() ?? 0,
        bookings: (j['bookings'] as num?)?.toInt() ?? 0,
      );
}

class ReEngagementResult {
  final int months, count;
  final List<ReEngagementClient> clients;
  const ReEngagementResult({this.months = 6, this.count = 0, this.clients = const []});
}

// ── Service ──────────────────────────────────────────────────────────────────
class MarketingInsightsService {
  final Dio _dio;
  MarketingInsightsService(this._dio);

  Future<MarketingInsights> getInsights({int? fyStartYear}) async {
    try {
      final res = await _dio.get('/marketing/insights',
          queryParameters: fyStartYear != null ? {'fy': fyStartYear} : null);
      return MarketingInsights.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load marketing insights'));
    }
  }

  Future<ReEngagementResult> getReEngagement({int months = 6}) async {
    try {
      final res = await _dio.get('/marketing/re-engagement',
          queryParameters: {'months': months});
      final d = res.data as Map<String, dynamic>;
      return ReEngagementResult(
        months: (d['months'] as num?)?.toInt() ?? months,
        count: (d['count'] as num?)?.toInt() ?? 0,
        clients: ((d['clients'] as List?) ?? const [])
            .map((e) => ReEngagementClient.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load re-engagement list'));
    }
  }

  /// [basis] = 'event' (bookingDate, the event day) or 'sales' (createdAt, the
  /// day the booking was made).
  Future<CalendarComparison> getCalendar({required int year, String basis = 'event'}) async {
    try {
      final res = await _dio.get('/marketing/calendar',
          queryParameters: {'year': year, 'basis': basis});
      return CalendarComparison.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load the booking calendar'));
    }
  }

  String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return e.message ?? fallback;
  }
}

// ── Providers ────────────────────────────────────────────────────────────────
final marketingInsightsServiceProvider = Provider<MarketingInsightsService>(
    (ref) => MarketingInsightsService(ref.watch(dioProvider)));

/// Selected financial-year start year (null = current FY).
final marketingFyProvider = StateProvider<int?>((ref) => null);

final marketingInsightsProvider = FutureProvider<MarketingInsights>((ref) async {
  final fy = ref.watch(marketingFyProvider);
  return ref.watch(marketingInsightsServiceProvider).getInsights(fyStartYear: fy);
});

/// Re-engagement "months since last event" threshold.
final reEngagementMonthsProvider = StateProvider<int>((ref) => 6);

final reEngagementProvider = FutureProvider<ReEngagementResult>((ref) async {
  final months = ref.watch(reEngagementMonthsProvider);
  return ref.watch(marketingInsightsServiceProvider).getReEngagement(months: months);
});

/// Selected calendar year for the YoY comparison calendar (defaults to now).
final calendarYearProvider = StateProvider<int>((ref) => DateTime.now().year);

/// Which date drives the calendar: 'event' (event day) or 'sales' (booked day).
final calendarBasisProvider = StateProvider<String>((ref) => 'event');

final bookingCalendarProvider =
    FutureProvider<CalendarComparison>((ref) async {
  final year = ref.watch(calendarYearProvider);
  final basis = ref.watch(calendarBasisProvider);
  return ref.watch(marketingInsightsServiceProvider).getCalendar(year: year, basis: basis);
});
