import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
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
