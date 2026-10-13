import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';

class ProvisionResult {
  final bool created;
  final bool emailSent;
  final String? setupLink;
  final String message;
  const ProvisionResult({
    this.created = false,
    this.emailSent = false,
    this.setupLink,
    this.message = '',
  });
  factory ProvisionResult.fromJson(Map<String, dynamic> j) => ProvisionResult(
        created: j['created'] as bool? ?? false,
        emailSent: j['emailSent'] as bool? ?? false,
        setupLink: j['setupLink'] as String?,
        message: j['message'] as String? ?? '',
      );
}

class BulkProvisionResult {
  final int created;
  final int invited;
  final int skipped;
  final int total;
  const BulkProvisionResult({this.created = 0, this.invited = 0, this.skipped = 0, this.total = 0});
  factory BulkProvisionResult.fromJson(Map<String, dynamic> j) => BulkProvisionResult(
        created: (j['created'] as num?)?.toInt() ?? 0,
        invited: (j['invited'] as num?)?.toInt() ?? 0,
        skipped: (j['skipped'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

class EssService {
  final Dio _dio;
  EssService(this._dio);

  Future<ProvisionResult> provision(String employeeId, {String role = 'employee'}) async {
    try {
      final res = await _dio.post('/auth/provision-employee', data: {
        'employeeId': employeeId,
        'role': role,
      });
      return ProvisionResult.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'create the login');
    }
  }

  Future<BulkProvisionResult> provisionAll() async {
    try {
      final res = await _dio.post('/auth/provision-employees');
      return BulkProvisionResult.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'invite all employees');
    }
  }
}

final essServiceProvider = Provider<EssService>((ref) => EssService(ref.watch(dioProvider)));
