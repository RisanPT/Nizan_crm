import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';
import 'package:nizan_crm/core/models/paginated_response.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/sales/services/lead_service.dart';
// LeadFilter is the request DTO used with these providers.
export 'package:nizan_crm/features/sales/services/lead_service.dart' show LeadFilter;

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
