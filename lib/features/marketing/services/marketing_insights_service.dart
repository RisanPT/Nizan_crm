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

class MarketingInsights {
  final NpsSummary nps;
  final double avgBrideScore, avgTeamScore;
  final int csatSubmitted;
  final int artistUtilPct, artistBusy, artistTotal;
  final SlotUtil slot;
  final List<SegmentRow> byRegion, byDistrict, byMonth, byCulture;
  final int totalBookings;

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
    this.byMonth = const [],
    this.byCulture = const [],
    this.totalBookings = 0,
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
      byMonth: rows('byMonth'),
      byCulture: rows('byCulture'),
      totalBookings: (seg['totalBookings'] as num?)?.toInt() ?? 0,
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
