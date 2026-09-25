import 'package:dio/dio.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'package:nizan_crm/core/error/errors.dart';


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
      throw AppException(e, action: 'load driver jobs');
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
      throw AppException(e, action: 'start trip');
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
    } catch (e) {
      throw AppException(e, action: 'complete job');
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
      throw AppException(e, action: 'report accident');
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
      throw AppException(e, action: 'submit review');
    }
  }

  Future<List<DriverReview>> getManagerReviews() async {
    try {
      final response = await _dio.get('/fleet/manager/reviews');
      return (response.data as List)
          .map((json) => DriverReview.fromJson(json))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load reviews');
    }
  }

  Future<List<AccidentReport>> getManagerAccidents() async {
    try {
      final response = await _dio.get('/fleet/manager/accidents');
      return (response.data as List)
          .map((json) => AccidentReport.fromJson(json))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load accidents');
    }
  }
  Future<List<FleetJob>> getManagerCompletedWorks() async {
    try {
      final response = await _dio.get('/fleet/manager/completed-works');
      return (response.data as List)
          .map((json) => FleetJob.fromJson(json))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load completed works');
    }
  }

  Future<List<ServiceReminder>> getManagerServiceReminders() async {
    try {
      final response = await _dio.get('/fleet/manager/service-reminders');
      return (response.data as List)
          .map((json) => ServiceReminder.fromJson(json))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load service reminders');
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
    } catch (e) {
      throw AppException(e, action: 'add reminder');
    }
  }

  Future<ServiceReminder> completeServiceReminder(String id) async {
    try {
      final response = await _dio.post('/fleet/manager/service-reminders/$id/complete');
      return ServiceReminder.fromJson(response.data['reminder']);
    } catch (e) {
      throw AppException(e, action: 'complete reminder');
    }
  }
}
