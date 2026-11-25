import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';
import 'package:nizan_crm/core/models/paginated_response.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/sales/services/lead_service.dart';
// LeadFilter is the request DTO used with these providers.
export 'package:nizan_crm/features/sales/services/lead_service.dart'
    show LeadFilter, LeadCluster, LeadClusterItem,
        LeadsReport, LeadReportBucket, LeadReportPoint;

/// Alert threshold: this many leads on the SAME event date + SAME place trigger
/// the demand popup on the Leads screen.
const int kLeadClusterThreshold = 25;

final leadServiceProvider = Provider<LeadService>((ref) {
  return LeadService(ref.watch(dioProvider));
});

final paginatedLeadsProvider = FutureProvider.family<PaginatedResponse<Lead>, LeadFilter>((ref, filter) async {
  return ref.watch(leadServiceProvider).getLeads(filter);
});

/// Leads fetched per request by [leadsProvider].
const int kAllLeadsPageSize = 1000;

/// EVERY lead the user may see (the server still applies role / region scope).
/// Used by the dashboards, lead details and period reports, which count and
/// chart the whole list — so it must not stop at one page. It used to load a
/// single page of 1000, which capped "Total leads" at 1,000 and dropped every
/// older lead from the charts. Pages after the first load in parallel.
final leadsProvider = FutureProvider<List<Lead>>((ref) async {
  final service = ref.watch(leadServiceProvider);
  final first = await service.getLeads(LeadFilter(limit: kAllLeadsPageSize));
  final pages = first.totalPages;
  if (pages <= 1 || first.items.length < kAllLeadsPageSize) return first.items;
  final rest = await Future.wait([
    for (var page = 2; page <= pages; page++)
      service.getLeads(LeadFilter(page: page, limit: kAllLeadsPageSize)),
  ]);
  // A lead added between page loads shifts the list by one, so drop repeats.
  final seen = <String>{};
  return [
    for (final res in [first, ...rest])
      for (final lead in res.items)
        if (lead.id.isEmpty || seen.add(lead.id)) lead,
  ];
});

/// Demand clusters — leads sharing the same event date + place at/above the
/// threshold. Drives the Leads screen popup + reopen badge.
final leadClustersProvider = FutureProvider<List<LeadCluster>>((ref) async {
  return ref.watch(leadServiceProvider).getLeadClusters(threshold: kLeadClusterThreshold);
});

/// Day/week/month lead report, keyed by (period, date 'YYYY-MM-DD') so changing
/// either refetches. Powers the marketing Leads Report screen.
final leadReportProvider =
    FutureProvider.family<LeadsReport, ({String period, String date})>((ref, key) async {
  final parts = key.date.split('-').map(int.parse).toList();
  final date = DateTime(parts[0], parts[1], parts[2]);
  return ref.watch(leadServiceProvider).getLeadsReport(period: key.period, date: date);
});
