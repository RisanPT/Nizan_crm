import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/finance/data/asset.dart';
import 'package:nizan_crm/features/finance/services/asset_service.dart';

final assetServiceProvider = Provider<AssetService>((ref) {
  return AssetService(ref.watch(dioProvider));
});

/// Assets by type: 'digital' | 'physical' | 'all'.
final assetsProvider =
    FutureProvider.family<List<Asset>, String>((ref, type) async {
  return ref.watch(assetServiceProvider).getAssets(type: type);
});

final assetStatsProvider = FutureProvider<AssetStats>((ref) async {
  return ref.watch(assetServiceProvider).getStats();
});
