import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// One changed field in an audit row.
class AuditChange {
  final String field;
  final Object? from;
  final Object? to;
  const AuditChange({required this.field, this.from, this.to});

  factory AuditChange.fromJson(Map<String, dynamic> j) =>
      AuditChange(field: j['field']?.toString() ?? '', from: j['from'], to: j['to']);
}

/// One HR / payroll change-log row (GET /api/audit).
class AuditLogEntry {
  final String id;
  final String entity;
  final String entityId;
  final String employeeId;
  final String action;
  final List<AuditChange> changes;
  final String byName;
  final DateTime? at;
  final String note;

  const AuditLogEntry({
    required this.id,
    required this.entity,
    this.entityId = '',
    this.employeeId = '',
    required this.action,
    this.changes = const [],
    this.byName = '',
    this.at,
    this.note = '',
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> j) => AuditLogEntry(
        id: j['_id']?.toString() ?? '',
        entity: j['entity']?.toString() ?? '',
        entityId: j['entityId']?.toString() ?? '',
        employeeId: j['employeeId']?.toString() ?? '',
        action: j['action']?.toString() ?? '',
        changes: (j['changes'] as List? ?? const [])
            .whereType<Map>()
            .map((c) => AuditChange.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
        byName: j['byName']?.toString() ?? '',
        at: j['at'] != null ? DateTime.tryParse(j['at'].toString()) : null,
        note: j['note']?.toString() ?? '',
      );
}

class AuditLogService {
  final Dio _dio;
  AuditLogService(this._dio);

  Future<List<AuditLogEntry>> getLogs({String? employeeId, String? entity, int limit = 100}) async {
    try {
      final response = await _dio.get('/audit', queryParameters: {
        if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
        if (entity != null && entity.isNotEmpty) 'entity': entity,
        'limit': limit,
      });
      final list = response.data is List ? response.data as List : const [];
      return list
          .whereType<Map>()
          .map((m) => AuditLogEntry.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load change history');
    }
  }
}

final auditLogServiceProvider = Provider<AuditLogService>((ref) {
  return AuditLogService(ref.watch(dioProvider));
});

/// Change history for one employee (all entities).
final employeeAuditLogProvider =
    FutureProvider.autoDispose.family<List<AuditLogEntry>, String>((ref, employeeId) {
  return ref.read(auditLogServiceProvider).getLogs(employeeId: employeeId, limit: 200);
});

/// Mirrors the backend `canSeeAllEmployeePay` (utils/hrAccess.js), which
/// gates GET /api/audit: admin / manager, any `staff` permission, payroll
/// (accounts / finance_head roles, staff.salaries, payables.admin_salaries,
/// payables.operations_salaries) or HRA (payables.hra).
bool canSeeChangeHistory(AuthSession? session) {
  if (session == null) return false;
  final role = session.role.trim().toLowerCase();
  if (role == 'admin' || role == 'manager') return true;
  if (role == 'accounts' || role == 'finance_head') return true;
  final perms = session.permissions.map((p) => p.toString()).toSet();
  bool has(String key) {
    if (perms.contains(key)) return true;
    final dot = key.indexOf('.');
    return dot > 0 && perms.contains(key.substring(0, dot));
  }

  if (perms.any((p) => p == 'staff' || p.startsWith('staff.'))) return true;
  return has('payables.admin_salaries') ||
      has('payables.operations_salaries') ||
      has('payables.hra');
}
