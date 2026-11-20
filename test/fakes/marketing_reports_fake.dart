import 'package:dio/dio.dart';
import 'package:nizan_crm/features/marketing/services/marketing_reports_service.dart';

// A test stand-in for the marketing Saved / Scheduled reports (backend /api/marketing/reports): what a tab kept, what it lists.

class FakeMarketingReports extends MarketingReportsService {
  FakeMarketingReports({this.savedList = const [], this.scheduleList = const [], this.canManage = false}) : super(Dio());
  List<MarketingSavedReport> savedList;
  List<MarketingReportSchedule> scheduleList;
  bool canManage;

  /// What the tabs asked to keep in "Saved reports".
  final kept = <Map<String, String>>[];

  @override
  Future<(bool, List<MarketingReportSchedule>)> schedules(String module) async => (canManage, scheduleList);

  @override
  Future<List<MarketingSavedReport>> saved(String module, {int limit = 20}) async => [for (final r in savedList) if (r.module.isEmpty || r.module == module) r];

  @override
  Future<MarketingSavedReport> save({required String module, required String kind, required String name, required String from, required String to, String brand = 'all'}) async {
    kept.add({'module': module, 'kind': kind, 'name': name, 'from': from, 'to': to, 'brand': brand});
    return MarketingSavedReport(id: 'kept${kept.length}', module: module, kind: kind, name: name, from: from, to: to, brand: brand, mine: true);
  }

  @override
  Future<MarketingReportSchedule> updateSchedule(String key, Map<String, dynamic> change) async => MarketingReportSchedule(key: key);

  @override
  Future<void> remove(String id) async {}
}
