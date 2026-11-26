import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/associates/data/associate_works.dart';
import 'package:nizan_crm/features/associates/data/temp_staff.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The Associate Works report (GET /api/associate-works) — read-only.
class AssociateWorksService {
  AssociateWorksService(this._dio);
  final Dio _dio;

  Future<AssociateWorksPage> page(AssociateWorksQuery q) async {
    try {
      final res = await _dio.get('/associate-works', queryParameters: q.toParams());
      return AssociateWorksPage.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'load the associate works');
    }
  }

  /// The review list for the old free-text "temporary staff" box (GET /api/associate-works/temp-staff).
  Future<TempStaffScan> tempStaff() async {
    try {
      final res = await _dio.get('/associate-works/temp-staff');
      return TempStaffScan.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'load the old temporary staff');
    }
  }

  /// Apply the reviewed rows (POST /api/associate-works/temp-staff/convert).
  Future<TempStaffResult> convertTempStaff(List<Map<String, dynamic>> rows) async {
    try {
      final res = await _dio.post('/associate-works/temp-staff/convert', data: {'rows': rows});
      return TempStaffResult.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'convert the temporary staff');
    }
  }

  /// Every work matching [q] (capped by the server), for a download.
  Future<AssociateWorksPage> export(AssociateWorksQuery q) async {
    try {
      final res = await _dio.get('/associate-works', queryParameters: q.toParams(export: true));
      return AssociateWorksPage.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'export the associate works');
    }
  }
}

final associateWorksServiceProvider = Provider<AssociateWorksService>((ref) => AssociateWorksService(ref.watch(dioProvider)));

/// One cached request per distinct query.
final associateWorksProvider = FutureProvider.autoDispose.family<AssociateWorksPage, AssociateWorksQuery>((ref, q) => ref.watch(associateWorksServiceProvider).page(q), retry: (_, _) => null);

typedef AssociateCsvSaver = Future<void> Function(String fileName, List<List<Object?>> rows);

/// Tests replace this to see what would be downloaded.
final associateCsvSaverProvider = Provider<AssociateCsvSaver>((ref) => downloadCsv);

/// The old temporary-staff names still waiting for review. Not cached: it is re-read each time the screen or banner is shown.
final tempStaffProvider = FutureProvider.autoDispose<TempStaffScan>((ref) => ref.watch(associateWorksServiceProvider).tempStaff(), retry: (_, _) => null);
