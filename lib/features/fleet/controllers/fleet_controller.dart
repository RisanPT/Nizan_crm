import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'package:nizan_crm/features/fleet/data/km_report.dart';
import 'package:nizan_crm/features/fleet/services/fleet_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

part 'fleet_controller.g.dart';

@riverpod
FleetService fleetService(Ref ref) {
  final dio = ref.watch(dioProvider);
  return FleetService(dio);
}

@riverpod
Future<List<FleetJob>> driverJobs(Ref ref) {
  return ref.watch(fleetServiceProvider).getDriverJobs();
}

@riverpod
Future<List<DriverReview>> managerReviews(Ref ref) {
  return ref.watch(fleetServiceProvider).getManagerReviews();
}

@riverpod
Future<List<AccidentReport>> managerAccidents(Ref ref) {
  return ref.watch(fleetServiceProvider).getManagerAccidents();
}

@riverpod
Future<List<FleetJob>> managerCompletedWorks(Ref ref) {
  return ref.watch(fleetServiceProvider).getManagerCompletedWorks();
}

@riverpod
Future<List<ServiceReminder>> managerServiceReminders(Ref ref) {
  return ref.watch(fleetServiceProvider).getManagerServiceReminders();
}

/// Inclusive date range for the fleet reports (dates only, local time).
typedef FleetDateRange = ({DateTime from, DateTime to});

/// Km report for a date range. Plain FutureProvider.family (not codegen) so
/// adding it needs no build_runner run.
final kmReportProvider =
    FutureProvider.autoDispose.family<KmReport, FleetDateRange>((ref, range) {
  return ref.watch(fleetServiceProvider).getKmReport(from: range.from, to: range.to);
});
