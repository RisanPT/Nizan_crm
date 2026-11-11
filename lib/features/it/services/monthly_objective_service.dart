import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/domain/models/monthly_objective.dart';
import 'package:nizan_crm/features/it/domain/models/monthly_trend.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// What the create / edit form sends for one key result. An existing one carries its [id] (so its history is kept).
class KeyResultInput {
  const KeyResultInput({this.id, required this.title, required this.targetValue, this.unit = '', this.currentValue, this.kind = 'number'});
  final String? id;
  final String title;

  /// number | percent | yesno — a percentage is out of 100 and a yes/no is done or not, so the server fixes their target.
  final String kind;
  final double targetValue;
  final String unit;
  final double? currentValue;

  Map<String, dynamic> toJson() => {
        if (id != null && id!.isNotEmpty) 'id': id,
        'title': title,
        'kind': kind,
        'targetValue': targetValue,
        'unit': unit,
        'currentValue': ?currentValue,
      };
}

class MonthlyObjectiveService {
  MonthlyObjectiveService(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(String action, Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  Map<String, dynamic> _map(Response r) => Map<String, dynamic>.from(r.data as Map);

  /// Every department's objectives for a month (the ones this person may see).
  Future<MonthlyObjectivesPage> getMonth(MonthKey m) => _guard('load the monthly objectives', () async {
        final r = await _dio.get('/monthly-objectives', queryParameters: {'year': m.year, 'month': m.month});
        return MonthlyObjectivesPage.fromJson(_map(r));
      });

  /// How the last [months] months went, ending with [end] — for the whole company and for each department this person may see.
  Future<MonthlyTrend> getTrend(MonthKey end, {int months = 6}) => _guard('load how the months went', () async {
        final r = await _dio.get('/monthly-objectives/trend', queryParameters: {'year': end.year, 'month': end.month, 'months': months});
        return MonthlyTrend.fromJson(_map(r));
      });

  Future<MonthlyObjective> create({
    required String departmentId,
    required MonthKey month,
    required String objective,
    String description = '',
    String priority = 'medium',
    String? ownerId,
    int spanMonths = 1,
    List<KeyResultInput> keyResults = const [],
  }) =>
      _guard('save the objective', () async {
        final r = await _dio.post('/monthly-objectives', data: {
          'departmentId': departmentId,
          'year': month.year,
          'month': month.month,
          'objective': objective,
          'description': description,
          'priority': priority,
          'ownerId': ownerId,
          'spanMonths': spanMonths,
          'keyResults': [for (final k in keyResults) k.toJson()],
        });
        return MonthlyObjective.fromJson(_map(r));
      });

  Future<MonthlyObjective> update(
    MonthlyObjective o, {
    required String objective,
    String description = '',
    String priority = 'medium',
    String? ownerId,
    int spanMonths = 1,
    String changeReason = '',
    List<KeyResultInput> keyResults = const [],
  }) =>
      _guard('save the objective', () async {
        final r = await _dio.put('/monthly-objectives/${o.id}', data: {
          'objective': objective,
          'description': description,
          'priority': priority,
          'ownerId': ownerId,
          'spanMonths': spanMonths,
          'keyResults': [for (final k in keyResults) k.toJson()],
          if (changeReason.isNotEmpty) 'changeReason': changeReason,
          'expectedUpdatedAt': o.updatedAt,
        });
        return MonthlyObjective.fromJson(_map(r));
      });

  /// Report progress on a key result: the new number, and / or "done".
  Future<MonthlyObjective> checkIn(String objectiveId, String keyResultId, {double? value, bool? completed}) => _guard('save the progress', () async {
        final r = await _dio.patch('/monthly-objectives/$objectiveId/key-results/$keyResultId', data: {'value': ?value, 'completed': ?completed});
        return MonthlyObjective.fromJson(_map(r));
      });

  Future<MonthlyObjective> close(String id, ObjectiveResult result, {String note = ''}) => _guard('close the objective', () async {
        final r = await _dio.post('/monthly-objectives/$id/close', data: {'result': result.slug, 'note': note});
        return MonthlyObjective.fromJson(_map(r));
      });

  Future<MonthlyObjective> reopen(String id) => _guard('reopen the objective', () async {
        final r = await _dio.post('/monthly-objectives/$id/reopen');
        return MonthlyObjective.fromJson(_map(r));
      });

  Future<void> delete(String id) => _guard('delete the objective', () async {
        await _dio.delete('/monthly-objectives/$id');
      });

  /// Carries the unfinished objectives into the next month; what is LEFT of each unfinished key result.
  Future<({List<MonthlyObjective> created, int skipped})> carryOver({required String departmentId, required MonthKey month, List<String>? ids}) =>
      _guard('carry the objectives over', () async {
        final r = await _dio.post('/monthly-objectives/carry-over', data: {'departmentId': departmentId, 'year': month.year, 'month': month.month, 'ids': ?ids});
        final j = _map(r);
        return (
          created: ((j['created'] as List?) ?? const []).map((e) => MonthlyObjective.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
          skipped: ((j['skipped'] as List?) ?? const []).length,
        );
      });
}

final monthlyObjectiveServiceProvider = Provider<MonthlyObjectiveService>((ref) => MonthlyObjectiveService(ref.watch(dioProvider)));

// A failing month says so (with Try again) instead of retrying behind a spinner.
final monthlyObjectivesProvider = FutureProvider.autoDispose.family<MonthlyObjectivesPage, MonthKey>(
  (ref, m) => ref.watch(monthlyObjectiveServiceProvider).getMonth(m),
  retry: (_, _) => null,
);

/// The last six months, for the trend line and the progress matrix. A side panel: when it fails it says so (the rest of the page
/// still works), and it is not retried behind a spinner.
final monthlyTrendProvider = FutureProvider.autoDispose.family<MonthlyTrend, MonthKey>(
  (ref, end) => ref.watch(monthlyObjectiveServiceProvider).getTrend(end),
  retry: (_, _) => null,
);
