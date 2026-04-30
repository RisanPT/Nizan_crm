import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/lead.dart';
import '../providers/dio_provider.dart';

final leadServiceProvider = Provider<LeadService>((ref) {
  return LeadService(ref.watch(dioProvider));
});

final leadsProvider = FutureProvider<List<Lead>>((ref) async {
  return ref.watch(leadServiceProvider).getLeads();
});

class LeadService {
  final Dio _dio;

  LeadService(this._dio);

  Future<List<Lead>> getLeads() async {
    try {
      final response = await _dio.get('/leads');
      final data = response.data as List;
      return data.map((item) => Lead.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load leads: ${e.message}');
    }
  }
}
