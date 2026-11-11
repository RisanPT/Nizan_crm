import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_cost_widgets.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

/// Finance's "Project budgets": the estimated costs waiting for the finance head. Nothing is spent against a project, and
/// the project cannot start, until its cost is approved here (as asked, or a different amount) — or sent back with what to
/// change. A change to an approved cost shows up here too, with the reason, while the earlier amount stays the limit.
/// The server decides who may open it (Finance) and who may decide (the finance head).
class ProjectBudgetsScreen extends ConsumerWidget {
  const ProjectBudgetsScreen({super.key});

  static final _day = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(pendingProjectCostsProvider);
    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pendingProjectCostsProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.payments_outlined, color: crm.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Project budgets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.4)),
                  Text('Estimated costs waiting for the finance head. A project cannot start until its cost is approved.', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            async.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(pendingProjectCostsProvider)),
              data: (rows) => rows.isEmpty
                  ? Container(
                      key: const Key('pb_empty'),
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      alignment: Alignment.center,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified_outlined, size: 32, color: crm.textSecondary.withValues(alpha: 0.6)),
                        const SizedBox(height: 8),
                        Text('Nothing is waiting for a decision.', style: TextStyle(fontSize: 13.5, color: crm.textSecondary)),
                      ]),
                    )
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('${rows.length} waiting', key: const Key('pb_count'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textSecondary)),
                      ),
                      for (final r in rows) ...[_card(context, ref, crm, r), const SizedBox(height: 12)],
                    ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, CrmTheme crm, PendingProjectCost r) {
    final meta = [
      if (r.department.isNotEmpty) r.department,
      if (r.managerName.isNotEmpty) 'managed by ${r.managerName}',
      if (r.requestedByName.isNotEmpty) 'asked by ${r.requestedByName}',
      if (r.requestedAt != null) _day.format(r.requestedAt!),
    ].join(' · ');
    final timeline = r.startDate == null ? '' : '${_day.format(r.startDate!)}${r.endDate == null ? '' : ' → ${_day.format(r.endDate!)}'}';
    return Container(
      key: Key('pb_card_${r.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              if (meta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(meta, style: TextStyle(fontSize: 12, color: crm.textSecondary))),
              if (timeline.isNotEmpty) Text(timeline, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ]),
          ),
          const SizedBox(width: 10),
          if (r.isChange)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFB45309).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _figure(crm, 'Asks for', rupees(r.budget), key: Key('pb_budget_${r.id}'))),
          if (r.isChange) Expanded(child: _figure(crm, 'Approved so far', rupees(r.approvedBudget), key: Key('pb_approved_${r.id}'))),
        ]),
        if (r.plan.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final l in r.plan)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(children: [
                Expanded(child: Text(costCategoryLabel(l.category), style: TextStyle(fontSize: 12, color: crm.textSecondary))),
                Text(rupees(l.amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
              ]),
            ),
        ],
        if (r.isChange && (r.changeReason.isNotEmpty || r.changeLines.isNotEmpty)) ...[
          const SizedBox(height: 8),
          Container(
            key: Key('pb_reason_${r.id}'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.changeReason.isNotEmpty) Text('Why: ${r.changeReason}', style: const TextStyle(fontSize: 12.5)),
              for (final l in r.changeLines) Text('• $l', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        if (r.canDecide)
          FilledButton.icon(
            key: Key('pb_decide_${r.id}'),
            onPressed: () async {
              final done = await showCostDecisionDialog(
                context,
                ref,
                id: r.id,
                name: r.name,
                department: r.department,
                requested: r.budget,
                approvedBudget: r.approvedBudget,
                changeReason: r.changeReason,
              );
              if (done != null) {
                ref.invalidate(pendingProjectCostsProvider);
                ref.invalidate(projectsProvider);
              }
            },
            icon: const Icon(Icons.fact_check_outlined, size: 16),
            label: const Text('Review & decide'),
          )
        else
          Text('Only the finance head decides.', key: Key('pb_view_only_${r.id}'), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
      ]),
    );
  }

  Widget _figure(CrmTheme crm, String label, String value, {Key? key}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        Text(value, key: key, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
      ]);
}
