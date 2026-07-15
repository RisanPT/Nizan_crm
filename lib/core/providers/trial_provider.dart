import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../services/trial_service.dart';
import '../models/trial.dart';

// ── Refresh trigger ───────────────────────────────────────────────────────────
final trialsRefreshTriggerProvider = StateProvider<int>((ref) => 0);

// ── Selected month (YYYY-MM) for filtering ────────────────────────────────────
final trialsMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  final m = now.month.toString().padLeft(2, '0');
  return '${now.year}-$m';
});

// ── All trials for the selected month ────────────────────────────────────────
final trialsProvider = FutureProvider.autoDispose<List<Trial>>((ref) async {
  ref.watch(trialsRefreshTriggerProvider);
  final month = ref.watch(trialsMonthProvider);
  return ref.watch(trialServiceProvider).getTrials(month: month);
});

// ── All trials (no month filter) — for the trials calendar ───────────────────
final allTrialsProvider = FutureProvider.autoDispose<List<Trial>>((ref) async {
  ref.watch(trialsRefreshTriggerProvider);
  return ref.watch(trialServiceProvider).getTrials();
});

// ── Single trial by ID ────────────────────────────────────────────────────────
final singleTrialProvider = FutureProvider.autoDispose.family<Trial?, String>((ref, id) async {
  if (id.isEmpty || id == 'new') return null;
  return ref.watch(trialServiceProvider).getTrialById(id);
});
