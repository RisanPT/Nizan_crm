import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';
import 'package:nizan_crm/features/it/domain/task_tree.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';

// Deleting a phase: the server deletes everything under it, so the lists on screen must drop all of it at once —
// not leave the phase's tasks behind as orphans until the next refresh.

ITTask _t(String id, {String? parent}) => ITTask(id: id, projectId: 'p1', title: id, parentTaskId: parent);

class _Repo implements IITTaskRepository {
  _Repo(this.tasks);
  List<ITTask> tasks;
  final deleted = <String>[];

  @override
  Future<List<ITTask>> getTasks({String? projectId, String? status, String? assignedTo, String? ticketType, String? severity, String? subTeam, String? search, bool mine = false}) async => tasks;

  @override
  Future<void> deleteTask(String id) async {
    deleted.add(id);
    final gone = {id, ...descendantIds(tasks, id)}; // what the server does
    tasks = tasks.where((t) => !gone.contains(t.id)).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

// phase 1 › task 1 › sub-task 1, task 2 · phase 2 › task 3
List<ITTask> _plan() => [_t('p1'), _t('t1', parent: 'p1'), _t('s1', parent: 't1'), _t('t2', parent: 'p1'), _t('p2'), _t('t3', parent: 'p2')];

void main() {
  late _Repo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _Repo(_plan());
    container = ProviderContainer(overrides: <Override>[itTaskRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
  });

  Future<List<String>> ids(ProviderListenable<AsyncValue<List<ITTask>>> p) async => [for (final t in container.read(p).requireValue) t.id];

  group('one project\'s tasks', () {
    final provider = itProjectTasksControllerProvider('p1');
    ITProjectTasksNotifier notifier() => container.read(provider.notifier);

    setUp(() async => container.listen(provider, (_, _) {})); // keep it alive

    test('deleting a phase drops its tasks and their sub-tasks too', () async {
      await container.read(provider.future);
      await notifier().deleteTask('p1');
      expect(repo.deleted, ['p1']);
      expect(await ids(provider), ['p2', 't3']);
    });

    test('deleting a task drops its sub-tasks, and leaves its phase and siblings', () async {
      await container.read(provider.future);
      await notifier().deleteTask('t1');
      expect(await ids(provider), ['p1', 't2', 'p2', 't3']);
    });

    test('deleting a task with nothing under it drops just that one', () async {
      await container.read(provider.future);
      await notifier().deleteTask('s1');
      expect(await ids(provider), ['p1', 't1', 't2', 'p2', 't3']);
    });

    test('deleting several at once drops each one\'s branch', () async {
      await container.read(provider.future);
      await notifier().bulkDelete(['t1', 'p2']);
      expect(await ids(provider), ['p1', 't2']);
    });
  });

  group('every project\'s tasks', () {
    final provider = itAllTasksControllerProvider;

    setUp(() async => container.listen(provider, (_, _) {}));

    test('deleting a phase drops its whole branch', () async {
      await container.read(provider.future);
      await container.read(provider.notifier).deleteTask('p1');
      expect(await ids(provider), ['p2', 't3']);
    });

    test('deleting several at once drops each one\'s branch', () async {
      await container.read(provider.future);
      await container.read(provider.notifier).bulkDelete(['t1', 'p2']);
      expect(await ids(provider), ['p1', 't2']);
    });
  });
}
