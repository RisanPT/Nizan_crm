import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/lead.dart';
import '../core/models/paginated_response.dart';
import '../providers/dio_provider.dart';

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

final leadServiceProvider = Provider<LeadService>((ref) {
  return LeadService(ref.watch(dioProvider));
});

final paginatedLeadsProvider = FutureProvider.family<PaginatedResponse<Lead>, LeadFilter>((ref, filter) async {
  return ref.watch(leadServiceProvider).getLeads(filter);
});

// Deprecated: use paginatedLeadsProvider instead. Keeping for backwards compatibility if needed.
final leadsProvider = FutureProvider<List<Lead>>((ref) async {
  final res = await ref.watch(leadServiceProvider).getLeads(LeadFilter(limit: 1000));
  return res.items;
});

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
}
