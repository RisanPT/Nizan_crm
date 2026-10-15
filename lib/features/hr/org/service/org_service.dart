import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/org/data/org_node.dart';

class OrgService {
  final Dio _dio;
  OrgService(this._dio);

  Future<List<OrgNode>> getOrgTree() async {
    try {
      final res = await _dio.get('/employees/org-tree');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => OrgNode.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load the org chart');
    }
  }

  /// Set who an employee reports to (and optionally their designation). Pass a
  /// null [managerId] to make them a top-level node (e.g. the CEO).
  Future<void> setReporting(String employeeId, {String? managerId, String? designationId}) async {
    try {
      await _dio.put('/employees/$employeeId/reporting', data: {
        'reportingManagerId': managerId ?? '',
        'designationId': ?designationId,
      });
    } catch (e) {
      throw AppException(e, action: 'update the reporting line');
    }
  }
}

final orgServiceProvider = Provider<OrgService>((ref) => OrgService(ref.watch(dioProvider)));

final orgTreeProvider = FutureProvider<List<OrgNode>>((ref) => ref.watch(orgServiceProvider).getOrgTree());
