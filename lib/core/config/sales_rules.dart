import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// Which bookings count toward SALES TOTALS (revenue figures).
///
/// A booking is left out of every sales total when the CRM user who ENTERED it
/// has "Count bookings in sales totals" switched off (Settings → Users). The
/// bookings still appear in lists / calendar; accounts, invoices, GST, client
/// spend and artist earnings are unaffected. The server applies the same rule
/// (nizan_crm_backend/utils/salesRules.js) to the totals it computes.

final Set<String> _excludedCreators = {};

/// True when a booking created by [createdBy] should be added to sales totals.
bool countsTowardSales({required String createdBy}) =>
    !_excludedCreators.contains(createdBy.trim());

/// Loads the excluded-creator list for the signed-in user. Screens that show
/// sales totals `ref.watch` this so they recompute once it arrives. Fails
/// open: if it can't be loaded, every booking counts (today's behaviour).
final salesExcludedCreatorsProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(authSessionProvider); // re-fetch on login / account switch
  try {
    final res =
        await ref.watch(dioProvider).get('/bookings/sales-excluded-creators');
    final ids = ((res.data as Map)['creatorIds'] as List? ?? const [])
        .map((e) => e.toString())
        .toSet();
    _excludedCreators
      ..clear()
      ..addAll(ids);
    return ids;
  } catch (_) {
    _excludedCreators.clear();
    return const <String>{};
  }
});
