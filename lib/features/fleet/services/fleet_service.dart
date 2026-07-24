import 'package:dio/dio.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';


class FleetService {
  final Dio _dio;

  FleetService(this._dio);

  Future<List<FleetJob>> getDriverJobs() async {
    try {
      final response = await _dio.get('/fleet/driver/jobs');
      return (response.data as List)
          .map((json) => FleetJob.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load driver jobs: $e');
    }
  }

  Future<FleetJob> startTripWithInspection(String jobId, List<String> photos) async {
    try {
      final response = await _dio.post(
        '/fleet/driver/inspection/$jobId',
        data: {'photos': photos},
      );
      return FleetJob.fromJson(response.data['job']);
    } catch (e) {
      throw Exception('Failed to start trip: $e');
    }
  }

  Future<({FleetJob job, bool isLastJob})> completeJob({required String jobId, String? parkedLocation}) async {
    try {
      final response = await _dio.post(
        '/fleet/driver/complete/$jobId',
        data: parkedLocation != null ? {'parkedLocation': parkedLocation} : {},
      );
      return (
        job: FleetJob.fromJson(response.data['job']),
        isLastJob: response.data['isLastJob'] == true,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to complete job: ${e.message}',
      );
    }
  }

  Future<AccidentReport> reportAccident({
    required String vehicleId,
    required String jobId,
    required double lat,
    required double lng,
    String? address,
    required List<String> photos,
    required String description,
    String oppositeName = '',
    String oppositePhone = '',
    String oppositeVehicle = '',
    String oppositeNotes = '',
  }) async {
    try {
      final response = await _dio.post(
        '/fleet/driver/accident',
        data: {
          'vehicleId': vehicleId,
          'jobId': jobId,
          'location': {
            'lat': lat,
            'lng': lng,
            if (address != null && address.trim().isNotEmpty)
              'address': address.trim(),
          },
          'photos': photos,
          'description': description,
          'opposite': {
            'name': oppositeName.trim(),
            'phone': oppositePhone.trim(),
            'vehicleNumber': oppositeVehicle.trim(),
            'notes': oppositeNotes.trim(),
          },
        },
      );
      return AccidentReport.fromJson(response.data['accident']);
    } catch (e) {
      throw Exception('Failed to report accident: $e');
    }
  }

  Future<DriverReview> submitDriverReview({
    required String driverId,
    required String jobId,
    required int rating,
    required String comment,
  }) async {
    try {
      final response = await _dio.post(
        '/fleet/review',
        data: {
          'driverId': driverId,
          'jobId': jobId,
          'rating': rating,
          'comment': comment,
        },
      );
      return DriverReview.fromJson(response.data['review']);
    } catch (e) {
      throw Exception('Failed to submit review: $e');
    }
  }

  Future<List<DriverReview>> getManagerReviews() async {
    try {
      final response = await _dio.get('/fleet/manager/reviews');
      return (response.data as List)
          .map((json) => DriverReview.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load reviews: $e');
    }
  }

  Future<List<AccidentReport>> getManagerAccidents() async {
    try {
      final response = await _dio.get('/fleet/manager/accidents');
      return (response.data as List)
          .map((json) => AccidentReport.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load accidents: $e');
    }
  }
  Future<List<FleetJob>> getManagerCompletedWorks() async {
    try {
      final response = await _dio.get('/fleet/manager/completed-works');
      return (response.data as List)
          .map((json) => FleetJob.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load completed works: $e');
    }
  }

  Future<List<ServiceReminder>> getManagerServiceReminders() async {
    try {
      final response = await _dio.get('/fleet/manager/service-reminders');
      return (response.data as List)
          .map((json) => ServiceReminder.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load service reminders: $e');
    }
  }

  Future<ServiceReminder> addServiceReminder({
    required String vehicleId,
    required String serviceType,
    DateTime? dueDate,
    double? dueKm,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '/fleet/manager/service-reminders',
        data: {
          'vehicle': vehicleId,
          'serviceType': serviceType,
          if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
          'dueKm': ?dueKm,
          'notes': ?notes,
        },
      );
      return ServiceReminder.fromJson(response.data['reminder']);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to add reminder: ${e.message}',
      );
    }
  }

  Future<ServiceReminder> completeServiceReminder(String id) async {
    try {
      final response = await _dio.post('/fleet/manager/service-reminders/$id/complete');
      return ServiceReminder.fromJson(response.data['reminder']);
    } catch (e) {
      throw Exception('Failed to complete reminder: $e');
    }
  }
}
