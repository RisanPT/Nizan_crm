import 'package:dio/dio.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';
import 'package:nizan_crm/core/models/paginated_response.dart';

/// A single lead inside a demand cluster (same event date + same place).
class LeadClusterItem {
  final String id;
  final String name;
  final String phone;
  final String status;
  final String priority;
  final DateTime? enquiryDate;
  final String location;

  const LeadClusterItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    required this.priority,
    required this.enquiryDate,
    required this.location,
  });

  factory LeadClusterItem.fromJson(Map<String, dynamic> j) => LeadClusterItem(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        status: (j['status'] ?? 'New').toString(),
        priority: (j['priority'] ?? 'Warm').toString(),
        enquiryDate: j['enquiryDate'] != null
            ? DateTime.tryParse(j['enquiryDate'].toString())?.toLocal()
            : null,
        location: (j['location'] ?? '').toString(),
      );
}

/// A group of leads all enquiring for the SAME event date at the SAME place,
/// whose size has reached the alert threshold. Powers the Leads demand popup.
class LeadCluster {
  final String date; // 'YYYY-MM-DD' (the event date being enquired for)
  final String place;
  final int count;
  final List<LeadClusterItem> leads;

  const LeadCluster({
    required this.date,
    required this.place,
    required this.count,
    required this.leads,
  });

  factory LeadCluster.fromJson(Map<String, dynamic> j) => LeadCluster(
        date: (j['date'] ?? '').toString(),
        place: (j['place'] ?? '').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
        leads: ((j['leads'] as List?) ?? const [])
            .map((e) => LeadClusterItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class LeadFilter {
  final int page;
  final int limit;
  final String search;
  final String status;
  final String source;
  final String salesperson;
  final String month;
  /// 'All', 'Hot', 'Warm' or 'Cold'.
  final String priority;

  LeadFilter({
    this.page = 1,
    this.limit = 20,
    this.search = '',
    this.status = 'All',
    this.source = 'All',
    this.salesperson = 'All',
    this.month = 'All',
    this.priority = 'All',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadFilter &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          limit == other.limit &&
          search == other.search &&
          status == other.status &&
          source == other.source &&
          salesperson == other.salesperson &&
          month == other.month &&
          priority == other.priority;

  @override
  int get hashCode =>
      page.hashCode ^
      limit.hashCode ^
      search.hashCode ^
      status.hashCode ^
      source.hashCode ^
      salesperson.hashCode ^
      month.hashCode ^
      priority.hashCode;
}

/// A single {label, count} slice of a lead report (by source / status / …).
class LeadReportBucket {
  final String key;
  final int count;
  const LeadReportBucket({required this.key, required this.count});
  factory LeadReportBucket.fromJson(Map<String, dynamic> j) => LeadReportBucket(
        key: (j['key'] ?? 'Unknown').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// One daily point of the report trend line.
class LeadReportPoint {
  final String date; // 'YYYY-MM-DD'
  final int count;
  const LeadReportPoint({required this.date, required this.count});
  factory LeadReportPoint.fromJson(Map<String, dynamic> j) => LeadReportPoint(
        date: (j['date'] ?? '').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// A day/week/month lead report with a like-for-like previous-period comparison.
class LeadsReport {
  final String period;
  final int total, prevTotal, converted, prevConverted, conversionRate, lost;
  final int followUpsDue, followUpsOverdue;
  final List<LeadReportBucket> bySource, byStatus, byPriority, byAddedBy, byAssignee;
  final List<LeadReportPoint> series;

  const LeadsReport({
    this.period = 'day',
    this.total = 0,
    this.prevTotal = 0,
    this.converted = 0,
    this.prevConverted = 0,
    this.conversionRate = 0,
    this.lost = 0,
    this.followUpsDue = 0,
    this.followUpsOverdue = 0,
    this.bySource = const [],
    this.byStatus = const [],
    this.byPriority = const [],
    this.byAddedBy = const [],
    this.byAssignee = const [],
    this.series = const [],
  });

  factory LeadsReport.fromJson(Map<String, dynamic> j) {
    List<LeadReportBucket> buckets(dynamic v) => ((v as List?) ?? const [])
        .map((e) => LeadReportBucket.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return LeadsReport(
      period: (j['period'] ?? 'day').toString(),
      total: (j['total'] as num?)?.toInt() ?? 0,
      prevTotal: (j['prevTotal'] as num?)?.toInt() ?? 0,
      converted: (j['converted'] as num?)?.toInt() ?? 0,
      prevConverted: (j['prevConverted'] as num?)?.toInt() ?? 0,
      conversionRate: (j['conversionRate'] as num?)?.toInt() ?? 0,
      lost: (j['lost'] as num?)?.toInt() ?? 0,
      followUpsDue: (j['followUpsDue'] as num?)?.toInt() ?? 0,
      followUpsOverdue: (j['followUpsOverdue'] as num?)?.toInt() ?? 0,
      bySource: buckets(j['bySource']),
      byStatus: buckets(j['byStatus']),
      byPriority: buckets(j['byPriority']),
      byAddedBy: buckets(j['byAddedBy']),
      byAssignee: buckets(j['byAssignee']),
      series: ((j['series'] as List?) ?? const [])
          .map((e) => LeadReportPoint.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class LeadService {
  final Dio _dio;

  LeadService(this._dio);

  Future<PaginatedResponse<Lead>> getLeads(LeadFilter filter) async {
    try {
      final response = await _dio.get(
        '/leads',
        queryParameters: {
          'page': filter.page,
          'limit': filter.limit,
          if (filter.search.isNotEmpty) 'search': filter.search,
          if (filter.status != 'All') 'status': filter.status,
          if (filter.priority != 'All') 'priority': filter.priority,
          if (filter.source != 'All') 'source': filter.source,
          if (filter.salesperson != 'All') 'salesperson': filter.salesperson,
          if (filter.month != 'All') 'month': filter.month,
        },
      );
      
      final data = response.data;
      if (data is Map<String, dynamic> && data.containsKey('items')) {
        return PaginatedResponse<Lead>.fromJson(data, (json) => Lead.fromJson(json));
      } else {
        // Fallback for old API format or missing pagination fields
        List leadsList = [];
        if (data is Map) {
          leadsList = (data['data'] ?? data['leads'] ?? data['items'] ?? []) as List;
        } else if (data is List) {
          leadsList = data;
        }
        final items = leadsList.map((item) => Lead.fromJson(item as Map<String, dynamic>)).toList();
        return PaginatedResponse<Lead>(
          items: items,
          totalItems: items.length,
          totalPages: 1,
          page: 1,
          limit: filter.limit,
        );
      }
    } on DioException catch (e) {
      throw Exception('Failed to load leads: ${e.message}');
    }
  }

  /// Leads that pile up on the same event date + same place (>= [threshold]).
  Future<List<LeadCluster>> getLeadClusters({int threshold = 25}) async {
    try {
      final response = await _dio.get(
        '/leads/clusters',
        queryParameters: {'threshold': threshold},
      );
      final data = response.data;
      final list = (data is Map ? data['clusters'] : data) as List? ?? const [];
      return list
          .map((e) => LeadCluster.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw Exception(_message(e, 'Failed to load lead clusters'));
    }
  }

  /// Day / week / month lead report around [date] (date-only; the server anchors
  /// the period in IST). [period] is 'day', 'week' or 'month'.
  Future<LeadsReport> getLeadsReport({required String period, required DateTime date}) async {
    String two(int n) => n.toString().padLeft(2, '0');
    try {
      final res = await _dio.get('/leads/report', queryParameters: {
        'period': period,
        'date': '${date.year}-${two(date.month)}-${two(date.day)}',
      });
      return LeadsReport.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw Exception(_message(e, 'Failed to load the lead report'));
    }
  }

  Future<void> updateLead(String id, Map<String, dynamic> data) async {
    try {
      await _dio.put('/leads/$id', data: data);
    } on DioException catch (e) {
      throw Exception('Failed to update lead: ${e.message}');
    }
  }

  Future<void> deleteLead(String id) async {
    try {
      await _dio.delete('/leads/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete lead: ${e.message}');
    }
  }

  Future<void> bulkAssignLeads(String userId) async {
    try {
      await _dio.post('/leads/bulk-assign', data: {'userId': userId});
    } on DioException catch (e) {
      throw Exception('Failed to bulk assign leads: ${e.message}');
    }
  }

  /// A Sales Executive requests marking a lead Lost (needs manager approval).
  /// Managers/admins close it as Lost directly (handled server-side).
  Future<void> requestLostApproval(
    String id, {
    required String reason,
    required String remarks,
    String competitorName = '',
    String? lostAttachment,
  }) async {
    try {
      await _dio.post('/leads/$id/request-lost', data: {
        'reason': reason,
        'remarks': remarks,
        'competitorName': competitorName,
        'lostAttachment': ?lostAttachment,
      });
    } on DioException catch (e) {
      throw Exception(_message(e, 'Failed to submit lost request'));
    }
  }

  /// A manager approves or rejects a pending lost request.
  Future<void> reviewLostApproval(
    String id, {
    required bool approve,
    String note = '',
  }) async {
    try {
      await _dio.post('/leads/$id/review-lost', data: {
        'decision': approve ? 'approved' : 'rejected',
        'note': note,
      });
    } on DioException catch (e) {
      throw Exception(_message(e, 'Failed to review lost request'));
    }
  }

  String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? fallback;
  }
}
