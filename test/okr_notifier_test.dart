import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/okr_notifier.dart';
import 'package:nizan_crm/features/it/services/okr_service.dart';

// A save, a check-in or a dragged bar refreshes the list. It must not flash the screen back to a
// spinner: a timeline built on the list would be torn down and lose its scroll position, zoom,
// collapsed rows and any open detail.

class _Service extends OKRService {
  _Service() : super(Dio());

  var calls = 0;
  Completer<List<OKRModel>>? hold;

  @override
  Future<List<OKRModel>> getOKRs({
    String? projectId,
    String? department,
    String? status,
    bool? completed,
    String? search,
    bool companyScope = false,
  }) async {
    calls++;
    if (hold != null) return hold!.future;
    return [OKRModel(id: 'a', objective: 'v$calls')];
  }
}

void main() {
  test('refreshing keeps the list on screen until the new one arrives', () async {
    final service = _Service();
    final container = ProviderContainer(overrides: <Override>[okrServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);

    final seen = <AsyncValue<List<OKRModel>>>[];
    container.listen(projectOKRsNotifierProvider('p1'), (_, next) => seen.add(next), fireImmediately: false);
    await container.read(projectOKRsNotifierProvider('p1').future);
    expect(container.read(projectOKRsNotifierProvider('p1')).value!.single.objective, 'v1');
    seen.clear();

    service.hold = Completer();
    final refreshing = container.read(projectOKRsNotifierProvider('p1').notifier).refresh();
    await Future<void>.delayed(Duration.zero);

    // while the new list is on its way, the old one is still what the screen shows. The screen reads
    // the state with `.when(...)`; a state that is "loading" calls its spinner branch even though it
    // still holds the old value, so that is what is checked.
    final during = container.read(projectOKRsNotifierProvider('p1'));
    expect(during.value!.single.objective, 'v1');
    expect(during.when(data: (_) => 'list', error: (_, _) => 'error', loading: () => 'spinner'), 'list');

    service.hold!.complete([OKRModel(id: 'a', objective: 'v2')]);
    await refreshing;
    expect(container.read(projectOKRsNotifierProvider('p1')).value!.single.objective, 'v2');
    expect(seen.every((s) => s.hasValue), isTrue, reason: 'every state in between had a list to show');
  });

  test('with nothing yet (a first load, or after an error) it does show that it is loading', () async {
    final service = _Service()..hold = Completer();
    final container = ProviderContainer(overrides: <Override>[okrServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);

    final first = container.read(projectOKRsNotifierProvider('p1').future);
    expect(container.read(projectOKRsNotifierProvider('p1')).isLoading, isTrue);
    service.hold!.complete([OKRModel(id: 'a', objective: 'x')]);
    await first;
  });
}
