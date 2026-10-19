import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/sales/data/goal_report.dart';
import 'package:nizan_crm/features/sales/presentation/widgets/goal_period_nav.dart';
import 'package:nizan_crm/features/sales/services/goal_service.dart';

/// Sales → Goals. Set the company target for each metric for a day, a week or
/// a month. Every period is stored on its own, so changing next month's goal
/// never touches this month's. Only admin / manager / sales & marketing
/// managers can edit; everyone else sees the goals read-only.
class SalesGoalsScreen extends ConsumerStatefulWidget {
  const SalesGoalsScreen({super.key});

  @override
  ConsumerState<SalesGoalsScreen> createState() => _SalesGoalsScreenState();
}

class _SalesGoalsScreenState extends ConsumerState<SalesGoalsScreen> {
  String _type = 'month';
  DateTime _date = dateOnly(DateTime.now());
  final _controllers = {for (final k in kGoalMetrics) k: TextEditingController()};
  String? _loadedKey;
  bool _saving = false;

  ({String periodType, String date}) get _q => (periodType: _type, date: ymd(_date));

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _text(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toString());

  void _load(GoalSet s) {
    final key = '${s.periodType}|${s.periodStart}';
    if (_loadedKey == key) return;
    _loadedKey = key;
    for (final k in kGoalMetrics) {
      _controllers[k]!.text = _text(s.goals[k]);
    }
  }

  Future<void> _save() async {
    final goals = <String, double?>{};
    for (final k in kGoalMetrics) {
      final t = _controllers[k]!.text.trim();
      if (t.isEmpty) {
        goals[k] = null;
        continue;
      }
      final v = double.tryParse(t);
      if (v == null || v < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${kGoalMetricLabels[k]} goal must be a number'), backgroundColor: Colors.red.shade700),
        );
        return;
      }
      goals[k] = v;
    }
    setState(() => _saving = true);
    try {
      await ref.read(goalServiceProvider).saveGoals(_type, ymd(_date), goals);
      ref.invalidate(goalSetProvider);
      ref.invalidate(goalReportProvider);
      ref.invalidate(mtdReportProvider);
      _loadedKey = null; // reload the saved values
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Goals saved for ${periodLabel(_type, _date)}'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(goalSetProvider(_q));
    final set = async.value;
    if (set != null) _load(set);
    final canEdit = set?.canEdit ?? false;

    return Scaffold(
      backgroundColor: crm.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Goals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              OutlinedButton.icon(
                onPressed: () => context.go('/sales/report'),
                icon: const Icon(Icons.bar_chart_rounded, size: 16),
                label: const Text('Report'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GoalPeriodNav(
            type: _type,
            date: _date,
            onType: (t) => setState(() => _type = t),
            onDate: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(goalSetProvider(_q))),
            data: (s) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: crm.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Targets for ${periodLabel(_type, _date)}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  canEdit
                      ? 'Leave a box empty for no target. Each $_type is saved separately — other periods are not changed.'
                      : 'You can view goals but not change them. Ask an admin, manager, or a sales / marketing manager.',
                  style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 14, runSpacing: 14, children: [
                  for (final k in kGoalMetrics)
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _controllers[k],
                        enabled: canEdit,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: InputDecoration(
                          labelText: kGoalMetricLabels[k],
                          prefixText: k == 'revenue' ? '₹ ' : null,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                ]),
                if (canEdit) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save goals'),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
