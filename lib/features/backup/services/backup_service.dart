import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';

/// One department the current user is allowed to back up.
class BackupTarget {
  final String key;
  final String label;
  final int collections;
  const BackupTarget(this.key, this.label, this.collections);

  factory BackupTarget.fromJson(Map j) => BackupTarget(
        (j['key'] ?? '').toString(),
        (j['label'] ?? '').toString(),
        (j['collections'] as num?)?.toInt() ?? 0,
      );
}

/// What the current user may back up: whether they can take a FULL backup, and
/// the list of departments they may export.
class BackupTargets {
  final bool full;
  final List<BackupTarget> departments;
  const BackupTargets({this.full = false, this.departments = const []});
}

final backupServiceProvider =
    Provider<BackupService>((ref) => BackupService(ref.watch(dioProvider)));

final backupTargetsProvider = FutureProvider<BackupTargets>(
    (ref) => ref.watch(backupServiceProvider).getTargets());

class BackupService {
  final Dio _dio;
  BackupService(this._dio);

  Future<BackupTargets> getTargets() async {
    final res = await _dio.get('/backup/departments');
    final m = (res.data as Map);
    return BackupTargets(
      full: m['full'] == true,
      departments: ((m['departments'] as List?) ?? const [])
          .map((e) => BackupTarget.fromJson(e as Map))
          .toList(),
    );
  }

  Future<List<int>> downloadDepartment(String key) async {
    final res = await _dio.get<List<int>>(
      '/backup/department/$key',
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data ?? const <int>[];
  }

  Future<List<int>> downloadFull() async {
    final res = await _dio.get<List<int>>(
      '/backup/full',
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data ?? const <int>[];
  }
}
