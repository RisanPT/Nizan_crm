import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/ceo/data/ceo_inbox.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

class CeoService {
  CeoService(this._dio);
  final Dio _dio;

  /// What needs the CEO, and what is waiting (and for how long) with the team.
  Future<CeoInbox> inbox() async {
    try {
      final res = await _dio.get('/ceo/inbox');
      return CeoInbox.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'load what needs your decision');
    }
  }

  /// The watch list, worst first.
  Future<List<CeoSignal>> signals() async {
    try {
      final res = await _dio.get('/ceo/signals');
      return (res.data as List).map((e) => CeoSignal.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      throw AppException(e, action: 'load the watch list');
    }
  }
}

final ceoServiceProvider = Provider<CeoService>((ref) => CeoService(ref.watch(dioProvider)));

// A failing card must say so, not spin for ever (Riverpod would retry a failed provider on its own).
final ceoInboxProvider = FutureProvider.autoDispose<CeoInbox>((ref) => ref.watch(ceoServiceProvider).inbox(), retry: (_, _) => null);

final ceoSignalsProvider = FutureProvider.autoDispose<List<CeoSignal>>((ref) => ref.watch(ceoServiceProvider).signals(), retry: (_, _) => null);
