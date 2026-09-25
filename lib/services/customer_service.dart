import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../providers/dio_provider.dart';
import '../models/customer.dart';

import '../core/auth/app_role.dart';
import '../core/providers/auth_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';

part 'customer_service.g.dart';

@riverpod
CustomerService customerService(Ref ref) {
  return CustomerService(ref.watch(dioProvider));
}

final customersProvider = FutureProvider<List<Customer>>((ref) {
  final service = ref.watch(customerServiceProvider);
  return service.getCustomers();
});

final paginatedCustomersProvider =
    FutureProvider.family<PaginatedListResponse<Customer>, ListPageParams>((
      ref,
      params,
    ) async {
      final authSession = ref.watch(authSessionProvider);
      final role = AppRole.fromString(authSession?.role);

      var zoneId = params.zoneId;
      var stateId = params.stateId;
      var regionId = params.regionId;
      var districtId = params.districtId;
      var pincodeId = params.pincodeId;

      if (!role.isFullAccess) {
        if (authSession != null) {
          if (authSession.zoneId.isNotEmpty) zoneId = authSession.zoneId;
          if (authSession.stateId.isNotEmpty) stateId = authSession.stateId;
          if (authSession.regionId.isNotEmpty) regionId = authSession.regionId;
          if (authSession.districtId.isNotEmpty) districtId = authSession.districtId;
          if (authSession.pincodeId.isNotEmpty) pincodeId = authSession.pincodeId;
        }
      }

      return ref.watch(customerServiceProvider).getPaginatedCustomers(
            page: params.page,
            limit: params.limit,
            search: params.search,
            status: params.status,
            sort: params.sort,
            zoneId: zoneId,
            stateId: stateId,
            regionId: regionId,
            districtId: districtId,
            pincodeId: pincodeId,
          );
    });

// ── Clients directory (server-side search / filter / sort / paging) ─────────

/// Everything the Clients directory asks the backend for. Value-equal so it
/// can key a provider family.
@immutable
class ClientQuery {
  const ClientQuery({
    this.page = 1,
    this.limit = 20,
    this.search = '',
    this.status = 'All',
    this.sort = 'newest',
    this.event = 'any',
    this.eventFrom,
    this.eventTo,
    this.addedFrom,
    this.addedTo,
  });

  final int page;
  final int limit;
  final String search;

  /// 'All' | 'Active' | 'Inactive' | 'Prospect'
  final String status;

  /// newest | oldest | name_asc | name_desc | event_soonest | event_latest
  final String sort;

  /// any | upcoming | past | none | range
  final String event;
  final DateTime? eventFrom;
  final DateTime? eventTo;
  final DateTime? addedFrom;
  final DateTime? addedTo;

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toQueryParams() => {
        'page': page,
        'limit': limit,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (status != 'All') 'status': status,
        'sort': sort,
        if (event != 'any') 'event': event,
        if (event == 'range' && eventFrom != null) 'eventFrom': _day(eventFrom!),
        if (event == 'range' && eventTo != null) 'eventTo': _day(eventTo!),
        if (addedFrom != null) 'addedFrom': _day(addedFrom!),
        if (addedTo != null) 'addedTo': _day(addedTo!),
      };

  @override
  bool operator ==(Object other) =>
      other is ClientQuery &&
      other.page == page &&
      other.limit == limit &&
      other.search == search &&
      other.status == status &&
      other.sort == sort &&
      other.event == event &&
      other.eventFrom == eventFrom &&
      other.eventTo == eventTo &&
      other.addedFrom == addedFrom &&
      other.addedTo == addedTo;

  @override
  int get hashCode => Object.hash(page, limit, search, status, sort, event,
      eventFrom, eventTo, addedFrom, addedTo);
}

/// A directory row: the customer plus the date it was added (not on the
/// generated [Customer] model).
class ClientRow {
  const ClientRow(this.customer, this.createdAt);
  final Customer customer;
  final DateTime? createdAt;

  factory ClientRow.fromJson(Map<String, dynamic> json) => ClientRow(
        Customer.fromJson(json),
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
      );
}

class ClientPage {
  const ClientPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.counts,
  });

  final List<ClientRow> items;
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;

  /// Matches per status for the current search/filters: All/Active/Inactive/Prospect.
  final Map<String, int> counts;

  factory ClientPage.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['counts'];
    return ClientPage(
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ClientRow.fromJson)
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      counts: rawCounts is Map
          ? rawCounts.map((k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0))
          : const {},
    );
  }
}

class ClientStats {
  const ClientStats({
    this.total = 0,
    this.active = 0,
    this.inactive = 0,
    this.prospect = 0,
    this.upcomingEvents = 0,
    this.eventsNext30Days = 0,
    this.addedThisMonth = 0,
  });

  final int total;
  final int active;
  final int inactive;
  final int prospect;
  final int upcomingEvents;
  final int eventsNext30Days;
  final int addedThisMonth;

  factory ClientStats.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return ClientStats(
      total: n('total'),
      active: n('active'),
      inactive: n('inactive'),
      prospect: n('prospect'),
      upcomingEvents: n('upcomingEvents'),
      eventsNext30Days: n('eventsNext30Days'),
      addedThisMonth: n('addedThisMonth'),
    );
  }
}

/// One page of the Clients directory. autoDispose so opening the screen always
/// refetches (clients are created from bookings elsewhere in the app).
final clientDirectoryProvider =
    FutureProvider.autoDispose.family<ClientPage, ClientQuery>((ref, q) {
  return ref.watch(customerServiceProvider).getClientDirectory(q);
});

final clientStatsProvider = FutureProvider.autoDispose<ClientStats>((ref) {
  return ref.watch(customerServiceProvider).getClientStats();
});

class CustomerService {
  final Dio _dio;

  CustomerService(this._dio);

  Future<ClientPage> getClientDirectory(ClientQuery q) async {
    try {
      final res = await _dio.get('/customers', queryParameters: q.toQueryParams());
      return ClientPage.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load clients');
    }
  }

  Future<ClientStats> getClientStats() async {
    try {
      final res = await _dio.get('/customers/stats');
      return ClientStats.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load client stats');
    }
  }

  Future<List<Customer>> getCustomers() async {
    try {
      final response = await _dio.get('/customers');
      final data = response.data as List;
      return data.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load customers');
    }
  }

  Future<PaginatedListResponse<Customer>> getPaginatedCustomers({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? sort,
    String? zoneId,
    String? stateId,
    String? regionId,
    String? districtId,
    String? pincodeId,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty && status != 'All') 'status': status,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        if (zoneId != null && zoneId.isNotEmpty) 'zoneId': zoneId,
        if (stateId != null && stateId.isNotEmpty) 'stateId': stateId,
        if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
        if (districtId != null && districtId.isNotEmpty) 'districtId': districtId,
        if (pincodeId != null && pincodeId.isNotEmpty) 'pincodeId': pincodeId,
      };
      final response = await _dio.get(
        '/customers',
        queryParameters: queryParams,
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        Customer.fromJson,
      );
    } catch (e) {
      throw AppException(e, action: 'load customers');
    }
  }

  Future<Customer> createCustomer(Customer customer) async {
    try {
      final response = await _dio.post(
        '/customers',
        data: customer.toJson(),
      );
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'create customer');
    }
  }

  Future<Customer> updateCustomer(String id, Customer customer) async {
    try {
      final response = await _dio.put(
        '/customers/$id',
        data: customer.toJson(),
      );
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update customer');
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _dio.delete('/customers/$id');
    } catch (e) {
      throw AppException(e, action: 'delete customer');
    }
  }
}
