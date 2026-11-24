import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/approvals/data/approval_models.dart';

class ApprovalService {
  final Dio _dio;
  ApprovalService(this._dio);

  List<ApprovalRequest> _list(dynamic data) {
    final raw = data is List ? data : const [];
    return raw.map((e) => ApprovalRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `module: 'leave'` → pending leave approvals for the leave desk (leave is
  /// not in the general inbox).
  Future<List<ApprovalRequest>> inbox({String? module}) async {
    try {
      final res = await _dio.get('/approvals/inbox',
          queryParameters: {'module': ?module});
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load approvals inbox');
    }
  }

  Future<List<ApprovalRequest>> mine() async {
    try {
      final res = await _dio.get('/approvals/mine');
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load my requests');
    }
  }

  Future<List<ApprovalRequest>> history({String? module, String? status}) async {
    try {
      final res = await _dio.get('/approvals/history', queryParameters: {
        if (module != null && module.isNotEmpty && module != 'all') 'module': module,
        if (status != null && status.isNotEmpty && status != 'all') 'status': status,
      });
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load approvals history');
    }
  }

  Future<void> approve(String id, {String note = ''}) async {
    try {
      await _dio.post('/approvals/$id/approve', data: {'note': note});
    } catch (e) {
      throw AppException(e, action: 'approve request');
    }
  }

  Future<void> reject(String id, {String note = ''}) async {
    try {
      await _dio.post('/approvals/$id/reject', data: {'note': note});
    } catch (e) {
      throw AppException(e, action: 'reject request');
    }
  }
}

final approvalServiceProvider =
    Provider<ApprovalService>((ref) => ApprovalService(ref.watch(dioProvider)));

final approvalInboxProvider =
    FutureProvider<List<ApprovalRequest>>((ref) => ref.watch(approvalServiceProvider).inbox());

final leaveInboxProvider = FutureProvider<List<ApprovalRequest>>(
    (ref) => ref.watch(approvalServiceProvider).inbox(module: 'leave'));

final myApprovalsProvider =
    FutureProvider<List<ApprovalRequest>>((ref) => ref.watch(approvalServiceProvider).mine());
