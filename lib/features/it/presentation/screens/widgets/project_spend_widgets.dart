import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/rupees.dart';
import 'package:nizan_crm/features/accounts/data/admin_expense.dart' show expenseHeadByCode;
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/data/project_spend.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// What a project has spent against the cost its finance head approved: a meter on the cost card, and a sheet that says where
// the money went and lists the expenses charged to the project.

/// The colour a level of spending wears: ok / warn (from 80%) / over.
Color spendLevelColor(String level) => switch (level) {
  'over' => const Color(0xFFB91C1C),
  'warn' => const Color(0xFFB45309),
  _ => const Color(0xFF15803D),
};

String spendLevelLabel(String level, double? fraction) => switch (level) {
  'over' => 'Over budget',
  'warn' => '${((fraction ?? 0.8) * 100).round()}% used',
  'ok' => '${((fraction ?? 0) * 100).round()}% used',
  _ => 'No limit yet',
};

/// A bar of what is spent and committed along the approved limit, with the figures under it.
class SpendMeter extends StatelessWidget {
  const SpendMeter({super.key, required this.cost});
  final ProjectCost cost;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final limit = cost.approvedBudget;
    final level = cost.level;
    final color = spendLevelColor(level);
    final spentShare = limit <= 0 ? 0.0 : (cost.spent / limit).clamp(0.0, 1.0);
    final usedShare = limit <= 0 ? 0.0 : (cost.used / limit).clamp(0.0, 1.0);
    return Column(
      key: const Key('spend_meter'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Spending',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textSecondary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(
                spendLevelLabel(level, cost.usedFraction),
                key: const Key('spend_level'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 9,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: crm.background)),
                // committed (waiting for approval) lighter, then spent solid on top
                FractionallySizedBox(
                  widthFactor: usedShare,
                  child: ColoredBox(key: const Key('spend_bar_used'), color: color.withValues(alpha: 0.35)),
                ),
                FractionallySizedBox(
                  widthFactor: spentShare,
                  child: ColoredBox(key: const Key('spend_bar_spent'), color: color),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _figure(crm, 'Spent', rupees(cost.spent), const Key('cost_spent')),
            if (cost.committed > 0) _figure(crm, 'Committed', rupees(cost.committed), const Key('cost_committed')),
            _figure(
              crm,
              cost.available < 0 ? 'Over by' : 'Left',
              rupees(cost.available.abs()),
              const Key('cost_left'),
              color: cost.available < 0 ? color : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _figure(CrmTheme crm, String label, String value, Key key, {Color? color}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
      Text(
        value,
        key: key,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color ?? crm.textPrimary),
      ),
    ],
  );
}

/// Where the project's money went, and every expense charged to it. Only for those who may see money.
Future<void> showProjectSpendSheet(BuildContext context, Project project) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _SpendSheet(project: project),
);

class _SpendSheet extends ConsumerWidget {
  const _SpendSheet({required this.project});
  final Project project;

  static final _day = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(projectSpendProvider(project.id));
    return Padding(
      key: const Key('spend_sheet'),
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: async.when(
        loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(projectSpendProvider(project.id))),
        data: (s) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Spending · ${project.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _row(crm, 'Approved by Finance', rupees(s.limit)),
              _row(crm, 'Spent (approved expenses)', rupees(s.spent), key: const Key('sheet_spent')),
              _row(crm, 'Committed (waiting for approval)', rupees(s.committed), key: const Key('sheet_committed')),
              _row(
                crm,
                s.available < 0 ? 'Over the budget by' : 'Left',
                rupees(s.available.abs()),
                key: const Key('sheet_left'),
                color: s.available < 0 ? spendLevelColor('over') : null,
              ),
              if (s.byHead.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Where it went',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary),
                ),
                const SizedBox(height: 6),
                for (final b in s.byHead.take(6))
                  _row(
                    crm,
                    b.key == 'other' ? 'No expense head' : (expenseHeadByCode(b.key)?.label ?? b.key),
                    rupees(b.total),
                    key: Key('sheet_head_${b.key}'),
                  ),
              ],
              if (s.byDepartment.length > 1) ...[
                const SizedBox(height: 14),
                Text(
                  'By department',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary),
                ),
                const SizedBox(height: 6),
                for (final b in s.byDepartment) _row(crm, b.key, rupees(b.total), key: Key('sheet_dept_${b.key}')),
              ],
              const SizedBox(height: 14),
              Text(
                'Expenses',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
              const SizedBox(height: 6),
              if (s.expenses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nothing has been charged to this project yet.',
                    key: const Key('sheet_empty'),
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                  ),
                )
              else
                for (final e in s.expenses) _expense(crm, e),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(CrmTheme crm, String label, String value, {Key? key, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        ),
        Text(
          value,
          key: key,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? crm.textPrimary),
        ),
      ],
    ),
  );

  Widget _expense(CrmTheme crm, ProjectSpendExpense e) {
    final statusColor = switch (e.status) {
      'approved' => const Color(0xFF15803D),
      'rejected' => const Color(0xFFB91C1C),
      _ => const Color(0xFFB45309),
    };
    final meta = [
      if (e.date != null) _day.format(e.date!),
      if (e.department.isNotEmpty) e.department,
      if (e.filedByName.isNotEmpty) 'filed by ${e.filedByName}',
    ].join(' · ');
    return Container(
      key: Key('spend_expense_${e.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: e.status == 'rejected' ? crm.textSecondary : crm.textPrimary,
                    decoration: e.status == 'rejected' ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (meta.isNotEmpty) Text(meta, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                if (e.overBudgetReason.isNotEmpty)
                  Text(
                    'Approved over the budget: ${e.overBudgetReason}',
                    style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: spendLevelColor('over')),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rupees(e.amount),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  e.status,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
