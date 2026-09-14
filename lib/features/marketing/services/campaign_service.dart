import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/features/marketing/data/campaign.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

class CampaignService {
  final Dio _dio;
  CampaignService(this._dio);

  Future<CampaignBoard> getCampaigns({String status = 'all'}) async {
    try {
      final res = await _dio.get('/marketing/campaigns',
          queryParameters: status == 'all' ? null : {'status': status});
      return CampaignBoard.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load campaigns'));
    }
  }

  Future<Campaign> save(Campaign c) async {
    try {
      final res = c.id.isEmpty
          ? await _dio.post('/marketing/campaigns', data: c.toJson())
          : await _dio.put('/marketing/campaigns/${c.id}', data: c.toJson());
      return Campaign.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to save campaign'));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/marketing/campaigns/$id');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to delete campaign'));
    }
  }

  String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return e.message ?? fallback;
  }
}

final campaignServiceProvider =
    Provider<CampaignService>((ref) => CampaignService(ref.watch(dioProvider)));

final campaignStatusFilterProvider = StateProvider<String>((ref) => 'all');

final campaignsProvider = FutureProvider<CampaignBoard>((ref) async {
  final status = ref.watch(campaignStatusFilterProvider);
  return ref.watch(campaignServiceProvider).getCampaigns(status: status);
});
