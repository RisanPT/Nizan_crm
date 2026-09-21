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

// Deprecated: use paginatedLeadsProvider instead. Keeping for backwards compatibility if needed.
final leadsProvider = FutureProvider<List<Lead>>((ref) async {
  final res = await ref.watch(leadServiceProvider).getLeads(LeadFilter(limit: 1000));
  return res.items;
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
