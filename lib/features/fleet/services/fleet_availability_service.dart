import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/fleet/data/fleet_availability.dart';

/// Who is free when: the driver / vehicle pickers' marks, and the fleet board for a day.
class FleetAvailabilityService {
  final Dio _dio;
  FleetAvailabilityService(this._dio);

  /// How every driver and vehicle stands for one booking's days.
  Future<BookingAvailability> forBooking(String bookingId) async {
    try {
      final response = await _dio.get('/fleet/availability/booking/$bookingId');
      return BookingAvailability.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw AppException(e, action: 'check who is free');
    }
  }

  /// One day on the board ([day] is 'YYYY-MM-DD').
  Future<FleetBoard> forDay(String day) async {
    try {
      final response = await _dio.get(
        '/fleet/availability/day',
        queryParameters: {'date': day},
      );
      return FleetBoard.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load the fleet board');
    }
  }
}
