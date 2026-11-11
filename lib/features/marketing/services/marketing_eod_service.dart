import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import '../data/marketing_eod_models.dart';

class MarketingEodService {
  final Dio _dio;
  MarketingEodService(this._dio);

  // ── Master Setup ──────────────────────────────────────────────────────────

  Future<MarketingSetupData> getSetupData() async {
    try {
      final res = await _dio.get('/marketing/eod/setup');
      return MarketingSetupData.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException(e, action: 'load marketing EOD setup master data');
    }
  }

  Future<void> saveGroup(Map<String, dynamic> data) async {
    try {
      await _dio.post('/marketing/eod/groups', data: data);
    } catch (e) {
      throw AppException(e, action: 'save activity group');
    }
  }

  Future<void> saveRole(Map<String, dynamic> data) async {
    try {
      await _dio.post('/marketing/eod/roles', data: data);
    } catch (e) {
      throw AppException(e, action: 'save role');
    }
  }

  Future<void> saveMetric(Map<String, dynamic> data) async {
    try {
      await _dio.post('/marketing/eod/metrics', data: data);
    } catch (e) {
      throw AppException(e, action: 'save metric');
    }
  }

  Future<void> saveRoleProfile({
    required String roleId,
    required List<String> metricIds,
    String? applyToExistingFromMonth,
  }) async {
    try {
      await _dio.post('/marketing/eod/role-profiles', data: {
        'roleId': roleId,
        'metricIds': metricIds,
        'applyToExistingFromMonth': ?applyToExistingFromMonth,
      });
    } catch (e) {
      throw AppException(e, action: 'save role profile template');
    }
  }

  Future<void> saveTeamMember(Map<String, dynamic> data) async {
    try {
      await _dio.post('/marketing/eod/members', data: data);
    } catch (e) {
      throw AppException(e, action: 'save team member');
    }
  }

  Future<List<MarketingMetricModel>> getMemberMetrics(String memberId, [String? month]) async {
    try {
      final res = await _dio.get('/marketing/eod/member-metrics', queryParameters: {
        'memberId': memberId,
        'month': ?month,
      });
      return (res.data as List? ?? [])
          .map((m) => MarketingMetricModel.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load member activity set');
    }
  }

  Future<void> saveMemberMetrics({
    required String memberId,
    required List<String> metricIds,
    String? month,
  }) async {
    try {
      await _dio.post('/marketing/eod/member-metrics', data: {
        'memberId': memberId,
        'metricIds': metricIds,
        'month': ?month,
      });
    } catch (e) {
      throw AppException(e, action: 'save member activity set');
    }
  }

  // ── Monthly Targets ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTargets([String? month]) async {
    try {
      final res = await _dio.get('/marketing/eod/targets', queryParameters: {
        'month': ?month,
      });
      return (res.data as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      throw AppException(e, action: 'load monthly targets');
    }
  }

  Future<void> saveTargets(String month, List<Map<String, dynamic>> targetList) async {
    try {
      await _dio.post('/marketing/eod/targets', data: {
        'month': month,
        'targetList': targetList,
      });
    } catch (e) {
      throw AppException(e, action: 'save monthly targets');
    }
  }

  Future<void> copyTargets(String fromMonth, String toMonth) async {
    try {
      await _dio.post('/marketing/eod/targets/copy', data: {
        'fromMonth': fromMonth,
        'toMonth': toMonth,
      });
    } catch (e) {
      throw AppException(e, action: 'copy targets from previous month');
    }
  }

  // ── Daily EOD ─────────────────────────────────────────────────────────────

  Future<MarketingEodEntryPayload> getEodEntry({String? date, String? memberId}) async {
    try {
      final q = <String, dynamic>{};
      if (date != null && date.isNotEmpty) q['date'] = date;
      if (memberId != null && memberId.isNotEmpty) q['memberId'] = memberId;

      final res = await _dio.get('/marketing/eod/entry', queryParameters: q);
      return MarketingEodEntryPayload.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException(e, action: 'load daily EOD entry');
    }
  }

  /// Saves the day's EOD. Returns the soft warnings (e.g. implausible counts).
  Future<List<String>> saveEodEntry(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/marketing/eod/entry', data: data);
      final body = res.data;
      if (body is Map && body['warnings'] is List) {
        return (body['warnings'] as List).map((w) => w.toString()).toList();
      }
      return const [];
    } catch (e) {
      throw AppException(e, action: 'save daily EOD entry');
    }
  }

  // ── Dashboards & Summary ──────────────────────────────────────────────────

  Future<MarketingIndividualDashboardData> getIndividualDashboard({
    String? month,
    String? memberId,
  }) async {
    try {
      final q = <String, dynamic>{};
      if (month != null && month.isNotEmpty) q['month'] = month;
      if (memberId != null && memberId.isNotEmpty) q['memberId'] = memberId;

      final res = await _dio.get('/marketing/eod/dashboard', queryParameters: q);
      return MarketingIndividualDashboardData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } catch (e) {
      throw AppException(e, action: 'load marketing individual dashboard');
    }
  }

  Future<MarketingTeamSummaryData> getTeamSummary({String? month}) async {
    try {
      final q = <String, dynamic>{};
      if (month != null && month.isNotEmpty) q['month'] = month;

      final res = await _dio.get('/marketing/eod/team-summary', queryParameters: q);
      return MarketingTeamSummaryData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } catch (e) {
      throw AppException(e, action: 'load marketing team summary');
    }
  }

  Future<MarketingMissedEodsData> getMissedEods({String? month}) async {
    try {
      final q = <String, dynamic>{};
      if (month != null && month.isNotEmpty) q['month'] = month;

      final res = await _dio.get('/marketing/eod/missed', queryParameters: q);
      return MarketingMissedEodsData.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } catch (e) {
      throw AppException(e, action: 'load missed EOD records');
    }
  }

  // ── Remarks & Sign-off ────────────────────────────────────────────────────

  Future<void> saveRemarks(Map<String, dynamic> data) async {
    try {
      await _dio.post('/marketing/eod/remarks', data: data);
    } catch (e) {
      throw AppException(e, action: 'save monthly remarks');
    }
  }

  Future<void> signOffMonth({
    required String memberId,
    required String month,
    required String action, // 'member_ack' | 'manager_sign'
  }) async {
    try {
      await _dio.post('/marketing/eod/sign-off', data: {
        'memberId': memberId,
        'month': month,
        'action': action,
      });
    } catch (e) {
      throw AppException(e, action: 'complete digital sign-off');
    }
  }

  Future<void> reopenMonth({
    required String memberId,
    required String month,
    String? reason,
  }) async {
    try {
      await _dio.post('/marketing/eod/reopen', data: {
        'memberId': memberId,
        'month': month,
        'reason': ?reason,
      });
    } catch (e) {
      throw AppException(e, action: 'reopen closed month');
    }
  }

  // ── Access, settings, reminders, audit, export ────────────────────────────

  Future<MarketingEodAccess> getMyAccess() async {
    try {
      final res = await _dio.get('/marketing/eod/me');
      return MarketingEodAccess.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException(e, action: 'load marketing EOD access');
    }
  }

  /// Active ERP users a team member can be linked to ({id, name, email, role}).
  Future<List<Map<String, dynamic>>> getLinkableUsers() async {
    try {
      final res = await _dio.get('/marketing/eod/users');
      return (res.data as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      throw AppException(e, action: 'load ERP users');
    }
  }

  Future<void> saveSettings(Map<String, dynamic> data) async {
    try {
      await _dio.post('/marketing/eod/settings', data: data);
    } catch (e) {
      throw AppException(e, action: 'save EOD settings');
    }
  }

  /// Nudges a member about a missed EOD. Returns the confirmation message.
  Future<String> sendReminder({required String memberId, required String date}) async {
    try {
      final res = await _dio.post('/marketing/eod/remind', data: {
        'memberId': memberId,
        'date': date,
      });
      return (res.data as Map?)?['message']?.toString() ?? 'Reminder sent.';
    } catch (e) {
      throw AppException(e, action: 'send EOD reminder');
    }
  }

  Future<List<Map<String, dynamic>>> getAuditLog({String? table, int limit = 100}) async {
    try {
      final res = await _dio.get('/marketing/eod/audit', queryParameters: {
        'table': ?table,
        'limit': limit,
      });
      return (res.data as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      throw AppException(e, action: 'load the EOD audit log');
    }
  }

  /// Raw EOD records for a month as table data ({headers, rows}).
  Future<({List<String> headers, List<List<dynamic>> rows})> exportRecords(String month) async {
    try {
      final res = await _dio.get('/marketing/eod/export', queryParameters: {'month': month});
      final body = (res.data as Map).cast<String, dynamic>();
      return (
        headers: (body['headers'] as List? ?? []).map((h) => h.toString()).toList(),
        rows: (body['rows'] as List? ?? []).map((r) => List<dynamic>.from(r as List)).toList(),
      );
    } catch (e) {
      throw AppException(e, action: 'export EOD records');
    }
  }

  // ── Weekly Page Stats (FR-18) ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getWeeklyPageStats({
    required String memberId,
    String? month,
  }) async {
    try {
      final res = await _dio.get('/marketing/eod/weekly-stats', queryParameters: {
        'memberId': memberId,
        'month': ?month,
      });
      return (res.data as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      throw AppException(e, action: 'load weekly page stats');
    }
  }

  Future<void> saveWeeklyPageStats(Map<String, dynamic> data) async {
    try {
      await _dio.post('/marketing/eod/weekly-stats', data: data);
    } catch (e) {
      throw AppException(e, action: 'save weekly page stat');
    }
  }
}

// ── Riverpod Providers ──────────────────────────────────────────────────────

final marketingEodServiceProvider = Provider<MarketingEodService>((ref) {
  return MarketingEodService(ref.watch(dioProvider));
});

final marketingEodAccessProvider = FutureProvider<MarketingEodAccess>((ref) async {
  return ref.watch(marketingEodServiceProvider).getMyAccess();
});

final marketingEodSetupProvider = FutureProvider<MarketingSetupData>((ref) async {
  final service = ref.watch(marketingEodServiceProvider);
  return service.getSetupData();
});

typedef EodEntryQuery = ({String date, String? memberId});

final marketingEodEntryProvider =
    FutureProvider.family<MarketingEodEntryPayload, EodEntryQuery>((ref, query) async {
  final service = ref.watch(marketingEodServiceProvider);
  return service.getEodEntry(date: query.date, memberId: query.memberId);
});

typedef DashboardQuery = ({String month, String? memberId});

final marketingIndividualDashboardProvider =
    FutureProvider.family<MarketingIndividualDashboardData, DashboardQuery>((ref, query) async {
  final service = ref.watch(marketingEodServiceProvider);
  return service.getIndividualDashboard(month: query.month, memberId: query.memberId);
});

final marketingTeamSummaryProvider =
    FutureProvider.family<MarketingTeamSummaryData, String>((ref, month) async {
  final service = ref.watch(marketingEodServiceProvider);
  return service.getTeamSummary(month: month);
});

final marketingMissedEodsProvider =
    FutureProvider.family<MarketingMissedEodsData, String>((ref, month) async {
  final service = ref.watch(marketingEodServiceProvider);
  return service.getMissedEods(month: month);
});
