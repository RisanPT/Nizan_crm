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
      final data = response.data;

      List leadsList;
      if (data is Map) {
        leadsList = (data['data'] ?? data['leads'] ?? data['items'] ?? []) as List;
      } else if (data is List) {
        leadsList = data;
      } else {
        leadsList = [];
      }

      return leadsList.map((item) => Lead.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load leads: ${e.message}');
    }
  }

  Future<void> updateLead(String id, Map<String, dynamic> data) async {
    try {
      await _dio.put('/leads/$id', data: data);
    } on DioException catch (e) {
      throw Exception('Failed to update lead: ${e.message}');
    }
  }

  Future<void> deleteLead(String id) async {
    try {
      await _dio.delete('/leads/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete lead: ${e.message}');
    }
  }

  Future<void> bulkAssignLeads(String userId) async {
    try {
      await _dio.post('/leads/bulk-assign', data: {'userId': userId});
    } on DioException catch (e) {
      throw Exception('Failed to bulk assign leads: ${e.message}');
    }
  }
}
