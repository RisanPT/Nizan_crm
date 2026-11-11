import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/consultation.dart';
import '../data/consultation_summary.dart';
import '../services/consultation_service.dart';
import '../data/stylist_client.dart';
import '../services/stylist_client_service.dart';

// ── Refresh trigger ───────────────────────────────────────────────────────────
// Bumped by `ref.refreshData.consultations()` after any change.
final consultationsRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// What a list / calendar screen asks for. A record, so two equal queries share
/// one cached provider instance.
typedef ConsultationQuery = ({
  String? from,
  String? to,
  String? status,
  String? stylistId,
});

// ── Consultations for a date range (IST day strings, YYYY-MM-DD) ──────────────
final consultationsProvider = FutureProvider.autoDispose
    .family<List<Consultation>, ConsultationQuery>((ref, q) async {
  ref.watch(consultationsRefreshTriggerProvider);
  return ref.watch(consultationServiceProvider).list(
        from: q.from,
        to: q.to,
        status: q.status,
        stylistId: q.stylistId,
      );
});

// ── Dashboard / report for a date range (null range = the current month) ────
typedef SummaryQuery = ({String? from, String? to});

final consultationSummaryProvider = FutureProvider.autoDispose
    .family<ConsultationSummary, SummaryQuery>((ref, q) async {
  ref.watch(consultationsRefreshTriggerProvider);
  return ref.watch(consultationServiceProvider).summary(from: q.from, to: q.to);
});

// ── One consultation (includes notes when the user may read them) ────────────
final consultationProvider =
    FutureProvider.autoDispose.family<Consultation, String>((ref, id) async {
  ref.watch(consultationsRefreshTriggerProvider);
  return ref.watch(consultationServiceProvider).getById(id);
});

// ── A client's consultations + derived SRS status (lead card, form) ──────────
final leadConsultationsProvider = FutureProvider.autoDispose
    .family<LeadConsultations, String>((ref, leadId) async {
  ref.watch(consultationsRefreshTriggerProvider);
  return ref.watch(consultationServiceProvider).forLead(leadId);
});

// ── Users who can be assigned a consultation ─────────────────────────────────
final consultationStylistsProvider =
    FutureProvider.autoDispose<List<ConsultationStylist>>((ref) async {
  return ref.watch(consultationServiceProvider).stylists();
});

// ── Stylist client files ─────────────────────────────────────────────────────
// Both watch the consultations trigger, so `ref.refreshData.consultations()`
// (after any call or client change) reloads them too.
final stylistClientsProvider =
    FutureProvider.autoDispose.family<List<StylistClient>, ClientQuery>((ref, q) async {
  ref.watch(consultationsRefreshTriggerProvider);
  return ref.watch(stylistClientServiceProvider).list(q);
});

final stylistClientProvider = FutureProvider.autoDispose.family<StylistClient, String>((ref, id) async {
  ref.watch(consultationsRefreshTriggerProvider);
  return ref.watch(stylistClientServiceProvider).getById(id);
});
