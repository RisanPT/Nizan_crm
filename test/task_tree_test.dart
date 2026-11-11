import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/domain/task_tree.dart';

// What hangs under a task, and the order a list of tasks reads in (phase, its tasks, their sub-tasks).

ITTask _t(String id, {String? parent, int order = 0}) => ITTask(id: id, projectId: 'p1', title: id.toUpperCase(), parentTaskId: parent, order: order);

List<String> _ids(Iterable<ITTask> l) => [for (final t in l) t.id];

void main() {
  moveTests();
  group('descendantIds', () {
    final plan = [
      _t('p1'),
      _t('t1', parent: 'p1'),
      _t('s1', parent: 't1'),
      _t('s2', parent: 't1'),
      _t('t2', parent: 'p1'),
      _t('p2'),
      _t('t3', parent: 'p2'),
    ];

    test('everything below a phase, however deep, and nothing beside it', () {
      expect(descendantIds(plan, 'p1'), {'t1', 's1', 's2', 't2'});
      expect(descendantIds(plan, 't1'), {'s1', 's2'});
    });

    test('a task with nothing under it, or one that is not there, has none', () {
      expect(descendantIds(plan, 's1'), isEmpty);
      expect(descendantIds(plan, 'nope'), isEmpty);
    });

    test('never the task itself, even in a loop of parents', () {
      final loop = [_t('a', parent: 'b'), _t('b', parent: 'a')];
      expect(descendantIds(loop, 'a'), {'b'});
    });
  });

  group('inPlanOrder', () {
    test('a phase, then its tasks, then each task\'s sub-tasks — with how far in each sits', () {
      final shuffled = [_t('s1', parent: 't1'), _t('t2', parent: 'p1', order: 2), _t('p1'), _t('t1', parent: 'p1', order: 1), _t('p2', order: 1), _t('t3', parent: 'p2')];
      final r = inPlanOrder(shuffled);
      expect(_ids(r.tasks), ['p1', 't1', 's1', 't2', 'p2', 't3']);
      expect(r.depth, {'p1': 0, 't1': 1, 's1': 2, 't2': 1, 'p2': 0, 't3': 1});
    });

    test('siblings go by their order, and ones that tie stay as they came', () {
      final r = inPlanOrder([_t('c'), _t('a', order: 1), _t('b'), _t('d')]);
      expect(_ids(r.tasks), ['c', 'b', 'd', 'a']);
    });

    test('a task whose parent is not in the list starts a branch of its own', () {
      final r = inPlanOrder([_t('x', parent: 'filtered-out'), _t('y', parent: 'x')]);
      expect(_ids(r.tasks), ['x', 'y']);
      expect(r.depth, {'x': 0, 'y': 1});
    });

    test('tasks that are each other\'s parents are still listed, once', () {
      final r = inPlanOrder([_t('a', parent: 'b'), _t('b', parent: 'a'), _t('c')]);
      expect(_ids(r.tasks)..sort(), ['a', 'b', 'c']);
      expect(r.tasks, hasLength(3));
    });

    test('nothing in, nothing out', () {
      final r = inPlanOrder(const []);
      expect(r.tasks, isEmpty);
      expect(r.depth, isEmpty);
    });
  });
}

// Moving a task one place up or down among its siblings: what to write, and nothing when it cannot go.
void moveTests() {
  group('orderAfterMove', () {
    // phase orders 10..13; tasks under p1 ordered 1, 2, 3
    final plan = [
      _t('a', order: 10),
      _t('b', order: 11),
      _t('c', order: 12),
      _t('x', parent: 'a', order: 1),
      _t('y', parent: 'a', order: 2),
      _t('z', parent: 'a', order: 3),
    ];

    test('when their orders differ, the two trade places and nothing else is touched', () {
      expect(orderAfterMove(plan, 'b', -1), {'b': 10, 'a': 11});
      expect(orderAfterMove(plan, 'b', 1), {'b': 12, 'c': 11});
      expect(orderAfterMove(plan, 'y', 1), {'y': 3, 'z': 2});
    });

    test('only among its own siblings: a task does not trade with another phase\'s tasks', () {
      expect(orderAfterMove(plan, 'x', -1), isEmpty); // first under its phase
      expect(orderAfterMove(plan, 'z', 1), isEmpty); // last under its phase
    });

    test('at either end, or not there, or no move: nothing to write', () {
      expect(orderAfterMove(plan, 'a', -1), isEmpty);
      expect(orderAfterMove(plan, 'c', 1), isEmpty);
      expect(orderAfterMove(plan, 'nope', 1), isEmpty);
      expect(orderAfterMove(plan, 'b', 0), isEmpty);
    });

    test('siblings that tie are numbered afresh, so the move sticks', () {
      final tied = [_t('a'), _t('b'), _t('c')]; // all order 0
      expect(orderAfterMove(tied, 'c', -1), {'c': 1, 'b': 2}); // a stays 0 · c 1 · b 2
      expect(orderAfterMove(tied, 'a', 1), {'a': 1, 'c': 2}); // b is 0 already: b · a · c, with nothing to write for b
    });

    test('doing the move really changes the reading order', () {
      final changes = orderAfterMove(plan, 'c', -1);
      final after = [for (final t in plan) changes.containsKey(t.id) ? ITTask(id: t.id, projectId: 'p1', title: t.title, parentTaskId: t.parentTaskId, order: changes[t.id]!) : t];
      expect(_ids(inPlanOrder(after).tasks), ['a', 'x', 'y', 'z', 'c', 'b']);
    });

    test('a parent that is not in the list counts as none', () {
      final tasks = [_t('r1', order: 1), _t('r2', parent: 'filtered', order: 2)];
      expect(orderAfterMove(tasks, 'r2', -1), {'r2': 1, 'r1': 2});
    });
  });
}
