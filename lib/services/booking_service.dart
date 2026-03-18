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

  Future<List<Booking>> getBookings() async {
    try {
      final response = await _dio.get('/bookings');
      final data = response.data as List;
      return data.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load bookings: ${e.message}');
    }
  }

  Future<Booking> createBooking(Booking booking) async {
    try {
      final response = await _dio.post(
        '/bookings',
        data: booking.toJson(),
      );
      return Booking.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to create booking: ${e.message}');
    }
  }

  Future<void> deleteBooking(String id) async {
    try {
      await _dio.delete('/bookings/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete booking: ${e.message}');
    }
  }
}
