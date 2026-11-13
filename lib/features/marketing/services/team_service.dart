import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The date range, brand and (for managers) member every Marketing screen filters by — one shared state, so switching tabs keeps it.
class TeamFilter {
  const TeamFilter({required this.from, required this.to, this.brand = TeamBrand.all, this.memberId});

  final DateTime from;
  final DateTime to;
  final TeamBrand brand;
  final String? memberId;

  /// This week, Monday to Sunday.
  factory TeamFilter.thisWeek({DateTime? now}) {
    final n = now ?? DateTime.now();
    final monday = DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
    return TeamFilter(from: monday, to: monday.add(const Duration(days: 6)));
  }

  static String day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String get fromDay => day(from);
  String get toDay => day(to);

  TeamFilter copyWith({DateTime? from, DateTime? to, TeamBrand? brand, String? memberId, bool clearMember = false}) =>
      TeamFilter(from: from ?? this.from, to: to ?? this.to, brand: brand ?? this.brand, memberId: clearMember ? null : (memberId ?? this.memberId));

  Map<String, dynamic> get query => {'from': fromDay, 'to': toDay, 'brand': brand.wire, 'memberId': ?memberId};

  @override
  bool operator ==(Object other) => other is TeamFilter && other.fromDay == fromDay && other.toDay == toDay && other.brand == brand && other.memberId == memberId;

  @override
  int get hashCode => Object.hash(fromDay, toDay, brand, memberId);
}

class MarketingTeamService {
  MarketingTeamService(this._dio);
  final Dio _dio;

  Future<T> _get<T>(String action, String path, T Function(Map<String, dynamic>) parse, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get('/marketing/team$path', queryParameters: query);
      return parse(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  Future<TeamOverview> overview(TeamFilter f) => _get('load the team dashboard', '/overview', TeamOverview.fromJson, query: f.query);
  Future<TeamActivityFeed> activity(TeamFilter f, {String? group, String? kind, int limit = 100}) =>
      _get('load the team activity', '/activity', TeamActivityFeed.fromJson, query: {...f.query, 'group': ?group, 'kind': ?kind, 'limit': limit});
  Future<Timesheet> timesheet(TeamFilter f) => _get('load the timesheet', '/timesheet', Timesheet.fromJson, query: f.query);
  Future<PerformanceData> performance(TeamFilter f) => _get('load performance', '/performance', PerformanceData.fromJson, query: f.query);
  Future<AttendanceData> attendance(String date) => _get('load attendance', '/attendance', AttendanceData.fromJson, query: {'date': date});
  Future<TeamReport> report(String type, TeamFilter f) => _get('build the report', '/reports/$type', TeamReport.fromJson, query: f.query);

  Future<LogSetup> logSetup({required String date, String? memberId}) => _get('open the log form', '/log-setup', LogSetup.fromJson, query: {'date': date, 'memberId': ?memberId});

  Future<TeamTaskList> tasks(TeamFilter f, {String status = 'all', String priority = 'all', String? q, bool mineOnly = false}) {
    final search = q?.trim() ?? '';
    return _get('load tasks', '/tasks', TeamTaskList.fromJson, query: {
      'brand': f.brand.wire,
      'status': status,
      'priority': priority,
      if (search.isNotEmpty) 'q': search,
      if (mineOnly) 'scope': 'mine',
      'assigneeId': ?f.memberId,
    });
  }

  /// Save a log (new, or [id] to change one). → warnings the server wants shown. Throws [TeamRefusal] for what it explains.
  Future<List<String>> saveLog(LogDraft draft, {String? id}) async {
    try {
      final res = id == null ? await _dio.post('/marketing/team/activities', data: draft.toJson()) : await _dio.put('/marketing/team/activities/$id', data: draft.toJson());
      return (((res.data as Map)['warnings'] as List?) ?? const []).map((w) => w.toString()).toList();
    } on DioException catch (e) {
      throw _refusal(e) ?? AppException(e, action: 'save the log');
    } catch (e) {
      throw AppException(e, action: 'save the log');
    }
  }

  Future<void> deleteLog(String id, {String reason = ''}) async {
    try {
      await _dio.delete('/marketing/team/activities/$id', queryParameters: {if (reason.trim().isNotEmpty) 'reason': reason.trim()});
    } on DioException catch (e) {
      throw _refusal(e) ?? AppException(e, action: 'delete the log');
    } catch (e) {
      throw AppException(e, action: 'delete the log');
    }
  }

  Future<TeamTask> saveTask(Map<String, dynamic> body, {String? id}) async {
    try {
      final res = id == null ? await _dio.post('/marketing/team/tasks', data: body) : await _dio.put('/marketing/team/tasks/$id', data: body);
      return TeamTask.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      throw _refusal(e) ?? AppException(e, action: 'save the task');
    } catch (e) {
      throw AppException(e, action: 'save the task');
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _dio.delete('/marketing/team/tasks/$id');
    } on DioException catch (e) {
      throw _refusal(e) ?? AppException(e, action: 'delete the task');
    } catch (e) {
      throw AppException(e, action: 'delete the task');
    }
  }

  Future<void> addComment(String taskId, String text) async {
    try {
      await _dio.post('/marketing/team/tasks/$taskId/comments', data: {'text': text});
    } on DioException catch (e) {
      throw _refusal(e) ?? AppException(e, action: 'add the comment');
    } catch (e) {
      throw AppException(e, action: 'add the comment');
    }
  }
}

/// The server's own explanation of a refusal (400 / 403 / 404 / 409 with a message), or null for anything else.
TeamRefusal? _refusal(DioException e) {
  final status = e.response?.statusCode;
  final data = e.response?.data;
  if (status == null || ![400, 403, 404, 409].contains(status) || data is! Map || data['message'] == null) return null;
  return TeamRefusal(data['message'].toString(), field: data['field']?.toString(), reasonRequired: data['reasonRequired'] == true, status: status);
}

final marketingTeamServiceProvider = Provider<MarketingTeamService>((ref) => MarketingTeamService(ref.watch(dioProvider)));

final teamFilterProvider = StateProvider<TeamFilter>((ref) => TeamFilter.thisWeek());

// A failing section must say so rather than spin for ever.
final teamOverviewProvider = FutureProvider.autoDispose<TeamOverview>((ref) => ref.watch(marketingTeamServiceProvider).overview(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final teamActivityProvider = FutureProvider.autoDispose<TeamActivityFeed>((ref) => ref.watch(marketingTeamServiceProvider).activity(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final teamTimesheetProvider = FutureProvider.autoDispose<Timesheet>((ref) => ref.watch(marketingTeamServiceProvider).timesheet(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final teamPerformanceProvider = FutureProvider.autoDispose<PerformanceData>((ref) => ref.watch(marketingTeamServiceProvider).performance(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final teamTasksProvider = FutureProvider.autoDispose<TeamTaskList>((ref) => ref.watch(marketingTeamServiceProvider).tasks(ref.watch(teamFilterProvider)), retry: (_, _) => null);

/// The attendance board for one day (the Attendance tab picks it).
final teamAttendanceProvider = FutureProvider.autoDispose.family<AttendanceData, String>((ref, date) => ref.watch(marketingTeamServiceProvider).attendance(date), retry: (_, _) => null);

/// What the Log Activity form needs for a date (and, for a manager, a member).
typedef LogSetupKey = ({String date, String? memberId});
final logSetupProvider = FutureProvider.autoDispose.family<LogSetup, LogSetupKey>((ref, k) => ref.watch(marketingTeamServiceProvider).logSetup(date: k.date, memberId: k.memberId), retry: (_, _) => null);

/// Re-read everything the team screens show (after a log, a task, a deletion).
void refreshTeam(WidgetRef ref) {
  ref.invalidate(teamOverviewProvider);
  ref.invalidate(teamActivityProvider);
  ref.invalidate(teamTimesheetProvider);
  ref.invalidate(teamPerformanceProvider);
  ref.invalidate(teamTasksProvider);
  ref.invalidate(teamAttendanceProvider);
  ref.invalidate(logSetupProvider);
}
