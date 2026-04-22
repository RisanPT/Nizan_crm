import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../providers/dio_provider.dart';
import '../core/models/booking.dart';

part 'booking_service.g.dart';

@riverpod
BookingService bookingService(Ref ref) {
  return BookingService(ref.watch(dioProvider));
}

class BookingService {
  final Dio _dio;

  BookingService(this._dio);

  String _extractErrorMessage(DioException error, String fallback) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final message = responseData['message']?.toString().trim() ?? '';
      if (message.isNotEmpty) return message;
    }

    final dioMessage = error.message?.trim() ?? '';
    if (dioMessage.isNotEmpty) return dioMessage;
    return fallback;
  }

  Future<List<Booking>> getBookings() async {
    try {
      final response = await _dio.get('/bookings');
      final data = response.data as List;
      return data
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        'Failed to load bookings: ${_extractErrorMessage(e, 'Unable to load bookings.')}',
      );
    }
  }

  Future<PaginatedBookingsResponse> getPaginatedBookings({
    int page = 1,
    int limit = 20,
    String search = '',
    bool duplicatesOnly = false,
    String? financialYear,
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
        },
      );
      return PaginatedBookingsResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        'Failed to load paginated bookings: ${_extractErrorMessage(e, 'Unable to load paginated bookings.')}',
      );
    }
  }

  Future<Booking> createBooking(Booking booking) async {
    try {
      final response = await _dio.post('/bookings', data: booking.toJson());
      return Booking.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        'Failed to create booking: ${_extractErrorMessage(e, 'Unable to create booking.')}',
      );
    }
  }

  Future<Booking> updateBooking(Booking booking) async {
    try {
      final response = await _dio.put(
        '/bookings/${booking.id}',
        data: booking.toJson(),
      );
      return Booking.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        'Failed to update booking: ${_extractErrorMessage(e, 'Unable to update booking.')}',
      );
    }
  }

  Future<void> deleteBooking(String id) async {
    try {
      await _dio.delete('/bookings/$id');
    } on DioException catch (e) {
      throw Exception(
        'Failed to delete booking: ${_extractErrorMessage(e, 'Unable to delete booking.')}',
      );
    }
  }
}
