import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/data/next_work_hint.dart';
import 'package:nizan_crm/core/error/errors.dart';

part 'booking_service.g.dart';

@riverpod
BookingService bookingService(Ref ref) {
  return BookingService(ref.watch(dioProvider));
}

class BookingService {
  final Dio _dio;

  BookingService(this._dio);


  Future<List<Booking>> getBookings() async {
    try {
      final response = await _dio.get('/bookings');
      final data = response.data as List;
      return data
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load bookings');
    }
  }

  Future<PaginatedBookingsResponse> getPaginatedBookings({
    int page = 1,
    int limit = 20,
    String search = '',
    bool duplicatesOnly = false,
    String? financialYear,
    String? employeeId,
    String? zoneId,
    String? stateId,
    String? regionId,
    String? districtId,
    String? pincodeId,
    String? dateBasis,
    String? month,
    bool onlyWithMapLink = false,
    String? status,
    String? from,
    String? to,
    String? salesPersonId,
    String? createdBy,
    String? packageId,
  }) async {
    try {
      final response = await _dio.get(
        '/bookings/paged',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (duplicatesOnly) 'duplicatesOnly': true,
          if (financialYear != null && financialYear.isNotEmpty)
            'financialYear': financialYear,
          if (employeeId != null && employeeId.isNotEmpty)
            'employeeId': employeeId,
          if (zoneId != null && zoneId.isNotEmpty) 'zoneId': zoneId,
          if (stateId != null && stateId.isNotEmpty) 'stateId': stateId,
          if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
          if (districtId != null && districtId.isNotEmpty) 'districtId': districtId,
          if (pincodeId != null && pincodeId.isNotEmpty) 'pincodeId': pincodeId,
          if (dateBasis != null && dateBasis.isNotEmpty) 'dateBasis': dateBasis,
          if (month != null && month.isNotEmpty) 'month': month,
          if (onlyWithMapLink) 'onlyWithMapLink': true,
          if (status != null && status.isNotEmpty) 'status': status,
          if (from != null && from.isNotEmpty) 'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
          if (salesPersonId != null && salesPersonId.isNotEmpty)
            'salesPersonId': salesPersonId,
          if (createdBy != null && createdBy.isNotEmpty) 'createdBy': createdBy,
          if (packageId != null && packageId.isNotEmpty) 'packageId': packageId,
        },
      );
      return PaginatedBookingsResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw AppException(e, action: 'load bookings');
    }
  }

  /// For each of the signed-in artist's works in [bookingIds]: where it falls in their
  /// day and the road to the next work. An artist's own works only (the server checks).
  Future<NextWorkHints> getNextWorkHints(List<String> bookingIds) async {
    if (bookingIds.isEmpty) return NextWorkHints.empty;
    try {
      final response = await _dio.get('/bookings/next-work', queryParameters: {'ids': bookingIds.join(',')});
      return NextWorkHints.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load the route between works');
    }
  }

  Future<Booking> getBookingById(String id) async {
    try {
      final response = await _dio.get('/bookings/$id');
      return Booking.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load the booking');
    }
  }

  /// [allowDuplicate] skips the server's same-number/same-date duplicate
  /// check, after the user confirmed they really want a second booking.
  Future<Booking> createBooking(Booking booking, {bool allowDuplicate = false}) async {
    try {
      final response = await _dio.post('/bookings', data: {
        ...booking.toJson(),
        if (allowDuplicate) 'allowDuplicate': true,
      });
      return Booking.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'create booking');
    }
  }

  /// [confirmFleetConflict]: the person has agreed to put a driver / vehicle on a work they are
  /// already committed to (the server otherwise answers 409 FLEET_CONFLICT for that).
  Future<Booking> updateBooking(Booking booking, {bool confirmFleetConflict = false}) async {
    try {
      final response = await _dio.put(
        '/bookings/${booking.id}',
        data: booking.toJson(),
        options: confirmFleetConflict ? Options(headers: {'X-Confirm-Fleet-Conflict': '1'}) : null,
      );
      return Booking.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update booking');
    }
  }

  Future<void> deleteBooking(String id) async {
    try {
      await _dio.delete('/bookings/$id');
    } catch (e) {
      throw AppException(e, action: 'delete booking');
    }
  }
}
