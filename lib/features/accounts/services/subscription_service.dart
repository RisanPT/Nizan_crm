import 'package:dio/dio.dart';
import 'package:nizan_crm/features/accounts/data/subscription.dart';

class SubscriptionStats {
  final int totalCount;
  final int activeCount;
  final double monthlyRunRate;
  final double annualizedCost;
  final int upcomingRenewalsCount;
  final Map<String, double> departmentBreakdown;
  final List<Subscription> renewalsNext30Days;

  const SubscriptionStats({
    required this.totalCount,
    required this.activeCount,
    required this.monthlyRunRate,
    required this.annualizedCost,
    required this.upcomingRenewalsCount,
    required this.departmentBreakdown,
    required this.renewalsNext30Days,
  });

  factory SubscriptionStats.fromJson(Map<String, dynamic> json) {
    final rawDept = json['departmentBreakdown'] as Map<String, dynamic>? ?? {};
    final deptMap = rawDept.map((k, v) => MapEntry(k, (v as num).toDouble()));

    final rawRenewals = json['renewalsNext30Days'] as List? ?? [];
    final renewals = rawRenewals
        .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
        .toList();

    return SubscriptionStats(
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
      monthlyRunRate: (json['monthlyRunRate'] as num?)?.toDouble() ?? 0,
      annualizedCost: (json['annualizedCost'] as num?)?.toDouble() ?? 0,
      upcomingRenewalsCount: (json['upcomingRenewalsCount'] as num?)?.toInt() ?? 0,
      departmentBreakdown: deptMap,
      renewalsNext30Days: renewals,
    );
  }
}

class SubscriptionService {
  final Dio _dio;

  SubscriptionService(this._dio);

  Future<List<Subscription>> getSubscriptions({
    String? department,
    String? status,
    String? billingCycle,
    String? search,
  }) async {
    try {
      final Map<String, dynamic> query = {};
      if (department != null && department.isNotEmpty && department != 'All') {
        query['department'] = department;
      }
      if (status != null && status.isNotEmpty && status != 'All' && status != 'all') {
        query['status'] = status;
      }
      if (billingCycle != null && billingCycle.isNotEmpty && billingCycle != 'All') {
        query['billingCycle'] = billingCycle;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }

      final response = await _dio.get(
        '/subscriptions',
        queryParameters: query.isNotEmpty ? query : null,
      );

      final list = response.data as List;
      return list
          .map((item) => Subscription.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to load subscriptions: ${e.message}');
    }
  }

  Future<SubscriptionStats> getStats() async {
    try {
      final response = await _dio.get('/subscriptions/stats');
      return SubscriptionStats.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to load subscription statistics: ${e.message}');
    }
  }

  Future<Subscription> createSubscription(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('/subscriptions', data: payload);
      return Subscription.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to create subscription: ${e.message}',
      );
    }
  }

  Future<Subscription> updateSubscription(
    String id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.put('/subscriptions/$id', data: payload);
      return Subscription.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to update subscription: ${e.message}',
      );
    }
  }

  Future<void> deleteSubscription(String id) async {
    try {
      await _dio.delete('/subscriptions/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete subscription: ${e.message}');
    }
  }
}
