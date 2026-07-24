import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/models/list_page_params.dart';
import 'package:nizan_crm/core/models/paginated_list_response.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/fleet/services/vehicle_service.dart';

final vehicleServiceProvider = Provider<VehicleService>((ref) {
  return VehicleService(ref.watch(dioProvider));
});

final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  return ref.watch(vehicleServiceProvider).getVehicles();
});

final paginatedVehiclesProvider =
    FutureProvider.family<PaginatedListResponse<Vehicle>, ListPageParams>((
      ref,
      params,
    ) async {
      return ref.watch(vehicleServiceProvider).getPaginatedVehicles(
            page: params.page,
            limit: params.limit,
          );
    });
