import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/fleet/data/fleet_availability.dart';
import 'package:nizan_crm/features/fleet/services/fleet_availability_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

final fleetAvailabilityServiceProvider = Provider<FleetAvailabilityService>(
  (ref) => FleetAvailabilityService(ref.watch(dioProvider)),
);

/// How every driver and vehicle stands for one booking. A failure just means no marks on the pickers.
final bookingAvailabilityProvider = FutureProvider.autoDispose
    .family<BookingAvailability, String>((ref, bookingId) {
      return ref.watch(fleetAvailabilityServiceProvider).forBooking(bookingId);
    });

/// The fleet board for one day ('YYYY-MM-DD').
final fleetBoardProvider = FutureProvider.autoDispose
    .family<FleetBoard, String>((ref, day) {
      return ref.watch(fleetAvailabilityServiceProvider).forDay(day);
    });
