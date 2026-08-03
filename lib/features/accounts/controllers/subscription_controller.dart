import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nizan_crm/features/accounts/data/subscription.dart';
import 'package:nizan_crm/features/accounts/services/subscription_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(ref.watch(dioProvider));
});

class SubscriptionFilter {
  final String department;
  final String status;
  final String billingCycle;
  final String search;

  const SubscriptionFilter({
    this.department = 'All',
    this.status = 'all',
    this.billingCycle = 'All',
    this.search = '',
  });

  SubscriptionFilter copyWith({
    String? department,
    String? status,
    String? billingCycle,
    String? search,
  }) {
    return SubscriptionFilter(
      department: department ?? this.department,
      status: status ?? this.status,
      billingCycle: billingCycle ?? this.billingCycle,
      search: search ?? this.search,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionFilter &&
          runtimeType == other.runtimeType &&
          department == other.department &&
          status == other.status &&
          billingCycle == other.billingCycle &&
          search == other.search;

  @override
  int get hashCode =>
      department.hashCode ^
      status.hashCode ^
      billingCycle.hashCode ^
      search.hashCode;
}

final subscriptionFilterProvider =
    StateProvider<SubscriptionFilter>((ref) => const SubscriptionFilter());

final subscriptionsProvider = FutureProvider<List<Subscription>>((ref) async {
  final filter = ref.watch(subscriptionFilterProvider);
  final service = ref.watch(subscriptionServiceProvider);
  return service.getSubscriptions(
    department: filter.department,
    status: filter.status,
    billingCycle: filter.billingCycle,
    search: filter.search,
  );
});

final subscriptionStatsProvider = FutureProvider<SubscriptionStats>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return service.getStats();
});
