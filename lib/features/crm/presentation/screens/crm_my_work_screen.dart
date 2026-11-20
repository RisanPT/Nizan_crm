import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/report_range.dart';
import 'package:nizan_crm/features/crm/data/crm_models.dart';
import 'package:nizan_crm/features/crm/presentation/screens/crm_dashboard_screen.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_care_todo.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_widgets.dart';
import 'package:nizan_crm/features/crm/services/crm_service.dart';

/// A CRM member's own work (/crm/my-work): what is theirs to do, the unassigned work they can take, and their figures for a period.
/// The head opens the same view for any member (/crm/team/:userId) — and can hand that member's work to someone else.
class CrmMyWorkScreen extends ConsumerStatefulWidget {
  const CrmMyWorkScreen({super.key, this.memberId, this.initialRange, this.now});

  /// Someone else's work (the head's view); null = mine.
  final String? memberId;
  final ReportRange? initialRange;
  final DateTime? now;

  @override
  ConsumerState<CrmMyWorkScreen> createState() => _CrmMyWorkScreenState();
}

class _CrmMyWorkScreenState extends ConsumerState<CrmMyWorkScreen> {
  late ReportRange _range = widget.initialRange ?? reportRangeFor(ReportPreset.thisMonth, widget.now ?? DateTime.now());
  final Set<String> _selected = {};

  bool get _isMine => widget.memberId == null;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final me = ref.watch(crmMeProvider);
    return Scaffold(
      backgroundColor: crm.background,
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmMeProvider)),
        data: (who) {
          final overview = ref.watch(crmOverviewProvider(CrmOverviewQuery(_range, memberId: widget.memberId)));
          final mine = ref.watch(crmQueueProvider(CrmQueueQuery(scope: _isMine ? 'mine' : null, memberId: widget.memberId)));
          final open = _isMine && who.canWrite ? ref.watch(crmQueueProvider(const CrmQueueQuery(scope: 'unassigned'))) : null;
          final name = _isMine ? 'My CRM work' : (overview.value?.memberName.isNotEmpty == true ? '${overview.value!.memberName}\'s CRM work' : 'CRM work');
          final canHandOn = !_isMine && who.canAssign;
          final items = mine.value?.items ?? const <CrmQueueItem>[];
          final chosen = items.where((i) => _selected.contains(CrmQueueList.keyOf(i))).toList();
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => refreshCrm(ref),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          if (!_isMine)
                            IconButton(tooltip: 'Back to the team', onPressed: () => context.go('/crm/dashboard'), icon: const Icon(Icons.arrow_back)),
                          Expanded(child: Text(name, key: const Key('crmMyWorkTitle'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: crm.textPrimary))),
                          IconButton(tooltip: 'Refresh', onPressed: () => refreshCrm(ref), icon: const Icon(Icons.refresh)),
                          OutlinedButton.icon(
                            key: const Key('crmMyReport'),
                            onPressed: () => downloadCrmReport(context, ref, initial: _range, memberId: widget.memberId, who: _isMine ? 'you' : (overview.value?.memberName ?? 'this member')),
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Report'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _section(crm, _isMine ? 'To do' : 'Their open work', mine.value?.counts['total'], mine.value?.counts['overdue']),
                      mine.when(
                        loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
                        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmQueueProvider)),
                        data: (q) => CrmQueueList(
                          items: q.items,
                          emptyText: _isMine ? 'Nothing waiting for you.' : 'Nothing open.',
                          selected: canHandOn ? _selected : null,
                          onToggle: canHandOn ? (i) => setState(() => _selected.contains(CrmQueueList.keyOf(i)) ? _selected.remove(CrmQueueList.keyOf(i)) : _selected.add(CrmQueueList.keyOf(i))) : null,
                          now: widget.now,
                        ),
                      ),
                      if (open != null) ...[
                        const SizedBox(height: 18),
                        _section(crm, 'Nobody has these yet — take one', open.value?.counts['total'], open.value?.counts['overdue']),
                        open.when(
                          loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
                          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmQueueProvider)),
                          data: (q) => CrmQueueList(
                            items: q.items,
                            emptyText: 'Everything has an owner.',
                            onTake: (i) => crmAssign(context, ref, [i], who.userId),
                            now: widget.now,
                          ),
                        ),
                      ],
                      // the works themselves: calls to confirm the coming week, photos still to collect
                      if (_isMine && who.canWrite) ...[
                        const SizedBox(height: 22),
                        const CrmCareToDo(kind: 'verify'),
                        const SizedBox(height: 18),
                        const CrmCareToDo(kind: 'photos'),
                      ],
                      const SizedBox(height: 22),
                      Text(_isMine ? 'My figures' : 'Their figures', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                      const SizedBox(height: 8),
                      CrmPeriodBar(range: _range, now: widget.now, onChanged: (r) => setState(() => _range = r)),
                      const SizedBox(height: 12),
                      overview.when(
                        loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
                        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmOverviewProvider)),
                        data: (o) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (o.partial) ...[CrmTrackingBanner(since: o.trackingSince), const SizedBox(height: 12)],
                            CrmKpiSection(title: 'Booking requests', specs: kCrmRequestKpis, kpiOf: o.kpi),
                            const SizedBox(height: 16),
                            CrmKpiSection(title: 'Client chat', specs: kCrmChatKpis, kpiOf: o.kpi),
                            const SizedBox(height: 16),
                            CrmKpiSection(title: 'Reviews and cases', specs: kCrmCareKpis, kpiOf: o.kpi),
                            const SizedBox(height: 16),
                            CrmKpiSection(title: 'Confirmations, trials and re-engagement', specs: kCrmGrowthKpis, kpiOf: o.kpi),
                            const SizedBox(height: 16),
                            CrmTrendCard(trend: o.trend),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (canHandOn && chosen.isNotEmpty)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: BoxDecoration(color: crm.surface, border: Border(top: BorderSide(color: crm.border))),
                    child: Row(children: [
                      Expanded(child: Text('${chosen.length} ticked', style: const TextStyle(fontWeight: FontWeight.w700))),
                      FilledButton.icon(
                        key: const Key('crmHandOn'),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Give to…'),
                        onPressed: () async {
                          final owner = await showCrmAssignDialog(context, count: chosen.length, title: 'Give to');
                          if (owner == null || !context.mounted) return;
                          if (await crmAssign(context, ref, chosen, owner)) setState(_selected.clear);
                        },
                      ),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(CrmTheme crm, String title, int? total, int? overdue) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary))),
        if (total != null) Text('$total', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textSecondary)),
        if ((overdue ?? 0) > 0) ...[const SizedBox(width: 8), Text('$overdue overdue', style: TextStyle(fontWeight: FontWeight.w700, color: crm.destructive))],
      ],
    ),
  );
}
