import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

// Saved and Scheduled reports of the Team Dashboard, Campaigns and Lead Report (backend /api/marketing/reports).

DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
String _s(Object? v) => v == null ? '' : v.toString();

/// A scheduled report: what it is, when it runs ("Every Monday, 10:00 AM"), whether it is on.
class MarketingReportSchedule {
  final String key, module, kind, label, cadence, time, when, updatedByName;
  final int weekday, dayOfMonth;
  final bool enabled;
  final DateTime? nextRunAt, lastRunAt;
  const MarketingReportSchedule({
    required this.key,
    this.module = '',
    this.kind = '',
    this.label = '',
    this.cadence = 'weekly',
    this.time = '10:00',
    this.when = '',
    this.updatedByName = '',
    this.weekday = 1,
    this.dayOfMonth = 1,
    this.enabled = false,
    this.nextRunAt,
    this.lastRunAt,
  });
  factory MarketingReportSchedule.fromJson(Map<String, dynamic> j) => MarketingReportSchedule(
    key: _s(j['key']),
    module: _s(j['module']),
    kind: _s(j['kind']),
    label: _s(j['label']),
    cadence: _s(j['cadence']),
    time: _s(j['time']),
    when: _s(j['when']),
    updatedByName: _s(j['updatedByName']),
    weekday: (j['weekday'] as num?)?.toInt() ?? 1,
    dayOfMonth: (j['dayOfMonth'] as num?)?.toInt() ?? 1,
    enabled: j['enabled'] == true,
    nextRunAt: _d(j['nextRunAt']),
    lastRunAt: _d(j['lastRunAt']),
  );
}

/// A report someone (or a schedule) generated: opening it runs the module's report again for its period.
class MarketingSavedReport {
  final String id, module, kind, name, from, to, brand, createdByName;
  final bool scheduled, mine;
  final DateTime? createdAt;
  const MarketingSavedReport({
    required this.id,
    this.module = '',
    this.kind = '',
    this.name = '',
    this.from = '',
    this.to = '',
    this.brand = 'all',
    this.createdByName = '',
    this.scheduled = false,
    this.mine = false,
    this.createdAt,
  });
  factory MarketingSavedReport.fromJson(Map<String, dynamic> j) => MarketingSavedReport(
    id: _s(j['id']),
    module: _s(j['module']),
    kind: _s(j['kind']),
    name: _s(j['name']),
    from: _s(j['from']),
    to: _s(j['to']),
    brand: _s(j['brand']).isEmpty ? 'all' : _s(j['brand']),
    createdByName: _s(j['createdByName']),
    scheduled: j['scheduled'] == true,
    mine: j['mine'] == true,
    createdAt: _d(j['createdAt']),
  );
}

class MarketingReportsService {
  MarketingReportsService(this._dio);
  final Dio _dio;

  Future<(bool, List<MarketingReportSchedule>)> schedules(String module) async {
    try {
      final res = await _dio.get('/marketing/reports/schedules', queryParameters: {'module': module});
      final b = (res.data as Map).cast<String, dynamic>();
      return (
        b['canManage'] == true,
        ((b['schedules'] as List?) ?? const []).whereType<Map>().map((e) => MarketingReportSchedule.fromJson(e.cast<String, dynamic>())).toList(),
      );
    } catch (e) {
      throw AppException(e, action: 'load the scheduled reports');
    }
  }

  Future<MarketingReportSchedule> updateSchedule(String key, Map<String, dynamic> change) async {
    try {
      final res = await _dio.put('/marketing/reports/schedules/$key', data: change);
      return MarketingReportSchedule.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException(e, action: 'change the scheduled report');
    }
  }

  Future<List<MarketingSavedReport>> saved(String module, {int limit = 20}) async {
    try {
      final res = await _dio.get('/marketing/reports/saved', queryParameters: {'module': module, 'limit': limit});
      return (((res.data as Map)['reports'] as List?) ?? const []).whereType<Map>().map((e) => MarketingSavedReport.fromJson(e.cast<String, dynamic>())).toList();
    } catch (e) {
      throw AppException(e, action: 'load the saved reports');
    }
  }

  /// Keeps a report the user just generated in "Saved reports".
  Future<MarketingSavedReport> save({required String module, required String kind, required String name, required String from, required String to, String brand = 'all'}) async {
    try {
      final res = await _dio.post('/marketing/reports/saved', data: {'module': module, 'kind': kind, 'name': name, 'from': from, 'to': to, 'brand': brand});
      return MarketingSavedReport.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException(e, action: 'save the report');
    }
  }

  Future<void> remove(String id) async {
    try {
      await _dio.delete('/marketing/reports/saved/$id');
    } catch (e) {
      throw AppException(e, action: 'remove the report');
    }
  }
}

final marketingReportsServiceProvider = Provider<MarketingReportsService>((ref) => MarketingReportsService(ref.watch(dioProvider)));

final marketingReportSchedulesProvider = FutureProvider.autoDispose.family<(bool, List<MarketingReportSchedule>), String>(
  (ref, module) => ref.watch(marketingReportsServiceProvider).schedules(module),
);

final marketingSavedReportsProvider = FutureProvider.autoDispose.family<List<MarketingSavedReport>, String>(
  (ref, module) => ref.watch(marketingReportsServiceProvider).saved(module),
);
