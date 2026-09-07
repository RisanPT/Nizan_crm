import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/hr/data/evaluation_models.dart';
import 'package:nizan_crm/features/hr/service/evaluation_service.dart';

/// HR 5-Pillar Evaluation — score each employee monthly on Learnability,
/// Responsibility, Punctuality, Commitment, Leadership. Dept heads evaluate
/// their own team; admins/managers evaluate anyone. Punctuality prefills from
/// attendance. Standalone scorecard (no automatic pay change).
class HrEvaluationScreen extends ConsumerWidget {
  const HrEvaluationScreen({super.key});

  static const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
      'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final session = ref.watch(authSessionProvider);
    final role = session?.role ?? '';
    final isAdmin = role == 'admin' || role == 'manager';
    final isHead = session?.isDepartmentHead ?? false;
    final canManage = isAdmin || isHead;

    final period = ref.watch(evalPeriodProvider);
    final employees = ref.watch(employeesProvider).value ?? const <Employee>[];
    final evalsAsync = ref.watch(evaluationsProvider);

    // Active staff, scoped to the dept head's own department.
    var staff = employees.where((e) => e.isActive).toList();
    if (!isAdmin && isHead && (session?.departmentName ?? '').isNotEmpty) {
      final dept = session!.departmentName.toLowerCase();
      staff = staff
          .where((e) => (e.department ?? '').toLowerCase() == dept)
          .toList();
    }

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(evaluationsProvider),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 14 : 24, 18, isMobile ? 14 : 24, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('5-Pillar Evaluations',
                          style: TextStyle(
                              fontSize: isMobile ? 21 : 26,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      Text(
                          'Learnability · Responsibility · Punctuality · Commitment · Leadership',
                          style: TextStyle(
                              fontSize: 11.5, color: crm.textSecondary)),
                    ],
                  ),
                ),
                _periodPicker(crm, ref, period),
              ],
            ),
            16.hg,
            evalsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: Center(
                  child: Text(e.toString().replaceFirst('Exception: ', ''),
                      style: TextStyle(color: crm.textSecondary)),
                ),
              ),
              data: (evals) {
                final byEmp = {for (final ev in evals) ev.employeeId: ev};
                final done = staff.where((e) => byEmp.containsKey(e.id)).length;
                final avg = evals.isEmpty
                    ? 0.0
                    : evals.map((e) => e.composite).reduce((a, b) => a + b) /
                        evals.length;

                // Evaluated first (highest composite), then unevaluated by name.
                staff.sort((a, b) {
                  final ea = byEmp[a.id], eb = byEmp[b.id];
                  if (ea != null && eb != null) {
                    return eb.composite.compareTo(ea.composite);
                  }
                  if (ea != null) return -1;
                  if (eb != null) return 1;
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _summary(crm, 'Evaluated', '$done / ${staff.length}',
                            const Color(0xFF6D5DF6)),
                        10.wg,
                        _summary(crm, 'Team Avg',
                            evals.isEmpty ? '—' : avg.toStringAsFixed(1),
                            _scoreColor(avg)),
                        10.wg,
                        _summary(crm, 'Period',
                            '${_mon[period.month]} ${period.year}',
                            const Color(0xFF0D9488)),
                      ],
                    ),
                    18.hg,
                    if (staff.isEmpty)
                      _muted(crm, 'No employees to evaluate.')
                    else
                      for (final e in staff)
                        _row(context, ref, crm, e, byEmp[e.id], period,
                            canManage),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, CrmTheme crm, Employee e,
      EmployeeEvaluation? ev, EvalPeriod period, bool canManage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: crm.primary.withValues(alpha: 0.12),
                child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: crm.primary, fontWeight: FontWeight.w800)),
              ),
              10.wg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: crm.textPrimary)),
                    Text(
                        '${e.role?.isNotEmpty == true ? e.role : (e.artistRole.isEmpty ? 'Staff' : e.artistRole)}'
                        '${(e.department ?? '').isNotEmpty ? ' · ${e.department}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: crm.textSecondary)),
                  ],
                ),
              ),
              if (ev != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _scoreColor(ev.composite).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100)),
                  child: Text(ev.composite.toStringAsFixed(1),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _scoreColor(ev.composite))),
                )
              else
                Text('Not evaluated',
                    style: TextStyle(fontSize: 11, color: crm.textSecondary)),
              if (canManage) ...[
                6.wg,
                TextButton(
                  onPressed: () =>
                      _openEditor(context, ref, e, ev, period),
                  child: Text(ev == null ? 'Evaluate' : 'Edit'),
                ),
              ],
            ],
          ),
          if (ev != null) ...[
            10.hg,
            Row(
              children: [
                for (final p in kPillars) ...[
                  Expanded(child: _pillarMini(crm, p, ev.pillar(p))),
                  if (p != kPillars.last) 6.wg,
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pillarMini(CrmTheme crm, String key, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kPillarLabels[key]!.substring(0, 4),
            style: TextStyle(fontSize: 9, color: crm.textSecondary)),
        3.hg,
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: (value / 5).clamp(0, 1),
            minHeight: 6,
            backgroundColor: crm.border,
            valueColor: AlwaysStoppedAnimation(_scoreColor(value)),
          ),
        ),
      ],
    );
  }

  // ── evaluate / edit dialog ──
  void _openEditor(BuildContext context, WidgetRef ref, Employee e,
      EmployeeEvaluation? existing, EvalPeriod period) {
    final scores = <String, double>{
      for (final p in kPillars) p: existing?.pillar(p) ?? 0,
    };
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    var punctualitySource = existing?.punctualitySource ?? 'manual';
    var saving = false;
    var prefilled = existing != null; // don't override an existing punctuality

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          // Auto-prefill Punctuality from attendance (match by name) once.
          if (!prefilled) {
            final att = ref.watch(periodAttendanceProvider(period));
            att.whenData((rows) {
              final match = rows.where((r) =>
                  r.employeeName.trim().toLowerCase() ==
                  e.name.trim().toLowerCase());
              if (match.isNotEmpty && !prefilled) {
                final pct = match.first.attendancePercent;
                scores['punctuality'] =
                    (pct / 20).clamp(0, 5).toDouble();
                punctualitySource = 'auto';
                prefilled = true;
              }
            });
          }
          final composite =
              kPillars.map((p) => scores[p]!).reduce((a, b) => a + b) /
                  kPillars.length;

          return AlertDialog(
            title: Text('Evaluate ${e.name}'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_mon[period.month]} ${period.year}',
                        style: TextStyle(
                            fontSize: 12,
                            color: context.crmColors.textSecondary)),
                    12.hg,
                    for (final p in kPillars) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(kPillarLabels[p]!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (p == 'punctuality' &&
                              punctualitySource == 'auto')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(100)),
                              child: const Text('Auto',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF16A34A))),
                            ),
                          Text(scores[p]!.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Slider(
                        value: scores[p]!.clamp(0, 5),
                        min: 0,
                        max: 5,
                        divisions: 10,
                        label: scores[p]!.toStringAsFixed(1),
                        onChanged: (v) => setLocal(() {
                          scores[p] = v;
                          if (p == 'punctuality') punctualitySource = 'manual';
                        }),
                      ),
                    ],
                    8.hg,
                    Row(
                      children: [
                        Text('Composite',
                            style: TextStyle(
                                color: context.crmColors.textSecondary)),
                        const Spacer(),
                        Text(composite.toStringAsFixed(1),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _scoreColor(composite))),
                      ],
                    ),
                    12.hg,
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setLocal(() => saving = true);
                        try {
                          await ref.read(evaluationServiceProvider).upsert(
                                employeeId: e.id,
                                month: period.month,
                                year: period.year,
                                learnability: scores['learnability']!,
                                responsibility: scores['responsibility']!,
                                punctuality: scores['punctuality']!,
                                commitment: scores['commitment']!,
                                leadership: scores['leadership']!,
                                punctualitySource: punctualitySource,
                                notes: notesCtrl.text.trim(),
                              );
                          ref.invalidate(evaluationsProvider);
                          ref.invalidate(employeeEvaluationsProvider(e.id));
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (err) {
                          setLocal(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(err
                                  .toString()
                                  .replaceFirst('Exception: ', '')),
                              backgroundColor: const Color(0xFFDC2626),
                            ));
                          }
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save'),
              ),
            ],
          );
        });
      },
    );
  }

  // ── period picker ──
  Widget _periodPicker(CrmTheme crm, WidgetRef ref, EvalPeriod p) {
    EvalPeriod shift(int delta) {
      var m = p.month + delta, y = p.year;
      if (m < 1) {
        m = 12;
        y -= 1;
      } else if (m > 12) {
        m = 1;
        y += 1;
      }
      return (year: y, month: m);
    }

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 18,
            onPressed: () =>
                ref.read(evalPeriodProvider.notifier).state = shift(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text('${_mon[p.month]} ${p.year}',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: crm.textPrimary)),
          IconButton(
            iconSize: 18,
            onPressed: () =>
                ref.read(evalPeriodProvider.notifier).state = shift(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _summary(CrmTheme crm, String label, String value, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: crm.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              Text(label,
                  style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            ],
          ),
        ),
      );

  Widget _muted(CrmTheme crm, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(t, style: TextStyle(color: crm.textSecondary)),
        ),
      );

  static Color _scoreColor(double v) {
    if (v >= 4) return const Color(0xFF16A34A);
    if (v >= 2.5) return const Color(0xFFF59E0B);
    if (v > 0) return const Color(0xFFDC2626);
    return const Color(0xFF6B7280);
  }
}

extension _Gap on num {
  Widget get hg => SizedBox(height: toDouble());
  Widget get wg => SizedBox(width: toDouble());
}
