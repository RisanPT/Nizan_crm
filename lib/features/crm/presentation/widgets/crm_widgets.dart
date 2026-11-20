import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/core/utils/report_range.dart';
import 'package:nizan_crm/core/widgets/report_range_dialog.dart';
import 'package:nizan_crm/features/crm/data/crm_models.dart';
import 'package:nizan_crm/features/crm/services/crm_service.dart';

/// The longest period the CRM dashboard and report cover (backend CRM_MAX_DAYS).
const kCrmMaxDays = 366;

final _dayTime = DateFormat('d MMM, h:mm a');

/// "overdue by 3 h" · "due in 40 min" · "due 20 Nov, 3:00 PM".
String crmDueText(DateTime? dueAt, {DateTime? now}) {
  if (dueAt == null) return '';
  final n = now ?? DateTime.now();
  final d = dueAt.difference(n);
  String span(Duration x) {
    final a = x.abs();
    if (a.inDays >= 2) return '${a.inDays} days';
    if (a.inHours >= 1) return '${a.inHours} h';
    return '${a.inMinutes.clamp(1, 59)} min';
  }

  if (d.isNegative) return 'overdue by ${span(d)}';
  if (d.inHours < 24) return 'due in ${span(d)}';
  return 'due ${_dayTime.format(dueAt)}';
}

String crmWhen(DateTime? d) => d == null ? '' : _dayTime.format(d);

// ── the period ──────────────────────────────────────────────────────────────

const _quick = [ReportPreset.today, ReportPreset.last7, ReportPreset.thisMonth, ReportPreset.lastMonth];

/// Today · Last 7 days · This month · Last month · a custom range (at most a year).
class CrmPeriodBar extends StatelessWidget {
  const CrmPeriodBar({super.key, required this.range, required this.onChanged, this.now});
  final ReportRange range;
  final ValueChanged<ReportRange> onChanged;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final today = now ?? DateTime.now();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in _quick)
          ChoiceChip(
            key: Key('crmPeriod_${p.name}'),
            label: Text(p.label),
            selected: range.preset == p,
            onSelected: (_) => onChanged(reportRangeFor(p, today)),
          ),
        ChoiceChip(
          key: const Key('crmPeriod_custom'),
          avatar: const Icon(Icons.date_range, size: 16),
          label: Text(range.preset == ReportPreset.custom ? range.label : 'Custom'),
          selected: range.preset == ReportPreset.custom,
          onSelected: (_) async {
            final r = await showReportRangeDialog(context, title: 'Which dates?', confirmLabel: 'Show', initial: range, maxDays: kCrmMaxDays, now: now);
            if (r != null) onChanged(ReportRange(from: r.from, to: r.to, preset: ReportPreset.custom).ordered);
          },
        ),
        if (range.preset != ReportPreset.custom) Text(range.label, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
      ],
    );
  }
}

// ── the figures ─────────────────────────────────────────────────────────────

/// What a KPI card says, and where.
class CrmKpiSpec {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const CrmKpiSpec(this.key, this.label, this.icon, this.color);
}

const kCrmRequestKpis = [
  CrmKpiSpec('requestsReceived', 'Requests received', Icons.inbox_outlined, Color(0xFF6366F1)),
  CrmKpiSpec('requestsDecided', 'Requests decided', Icons.task_alt, Color(0xFF10B981)),
  CrmKpiSpec('requestMedianHours', 'Time to decide', Icons.timer_outlined, Color(0xFFF59E0B)),
  CrmKpiSpec('requestWithinSlaPct', 'Decided in time', Icons.verified_outlined, Color(0xFF0EA5E9)),
];
const kCrmChatKpis = [
  CrmKpiSpec('chatWaits', 'Clients waiting in chat', Icons.forum_outlined, Color(0xFF6366F1)),
  CrmKpiSpec('chatMedianReplyMins', 'Time to answer', Icons.timer_outlined, Color(0xFFF59E0B)),
  CrmKpiSpec('chatWithinSlaPct', 'Answered in time', Icons.verified_outlined, Color(0xFF0EA5E9)),
  CrmKpiSpec('chatUnanswered', 'Left unanswered', Icons.speaker_notes_off_outlined, Color(0xFFEF4444)),
];
const kCrmCareKpis = [
  CrmKpiSpec('nps', 'NPS', Icons.sentiment_satisfied_alt_outlined, Color(0xFF10B981)),
  CrmKpiSpec('reviewResponseRate', 'Reviews answered', Icons.rate_review_outlined, Color(0xFF6366F1)),
  CrmKpiSpec('casesOpened', 'Cases opened', Icons.report_problem_outlined, Color(0xFFEF4444)),
  CrmKpiSpec('caseOnTimePct', 'Cases resolved on time', Icons.verified_outlined, Color(0xFF0EA5E9)),
];
const kCrmGrowthKpis = [
  CrmKpiSpec('confirmationsSent', 'Confirmations sent', Icons.send_outlined, Color(0xFF10B981)),
  CrmKpiSpec('trialConversionPct', 'Trials that booked', Icons.auto_awesome_outlined, Color(0xFFEC4899)),
  CrmKpiSpec('reCalls', 'Re-engagement calls', Icons.call_outlined, Color(0xFF6366F1)),
  CrmKpiSpec('reWins', 'Re-engagement wins', Icons.emoji_events_outlined, Color(0xFFF59E0B)),
];

class CrmKpiTile extends StatelessWidget {
  const CrmKpiTile({super.key, required this.spec, required this.kpi});
  final CrmKpiSpec spec;
  final CrmKpi kpi;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final improved = kpi.improved;
    final changeColor = improved == null ? crm.textSecondary : (improved ? crm.success : crm.destructive);
    final note = kpi.changeText ?? (kpi.value == null ? 'not recorded for this period' : (kpi.prev == null ? 'nothing to compare with' : 'same as before'));
    return Container(
      key: Key('crmKpi_${spec.key}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: spec.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(spec.icon, size: 16, color: spec.color),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(spec.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, height: 1.2, color: crm.textSecondary))),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(kpi.display, key: Key('crmKpiValue_${spec.key}'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kpi.value == null ? crm.textSecondary : crm.textPrimary)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (improved != null) ...[Icon(kpi.change! > 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: changeColor), const SizedBox(width: 2)],
              Expanded(child: Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: changeColor))),
            ],
          ),
          if (kpi.n != null && kpi.value != null && kpi.unit != 'count')
            Text('from ${kpi.n} ${kpi.n == 1 ? 'record' : 'records'}', style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
        ],
      ),
    );
  }
}

/// A titled group of KPI cards: four across on a wide screen, two on a phone.
class CrmKpiSection extends StatelessWidget {
  const CrmKpiSection({super.key, required this.title, required this.specs, required this.kpiOf});
  final String title;
  final List<CrmKpiSpec> specs;
  final CrmKpi Function(String key) kpiOf;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth < 640 ? 2 : 4;
            const gap = 12.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(spacing: gap, runSpacing: gap, children: [for (final s in specs) SizedBox(width: w, child: CrmKpiTile(spec: s, kpi: kpiOf(s.key)))]);
          },
        ),
      ],
    );
  }
}

/// "The CRM records began on …" — shown when the period starts before then (who owned and decided the work is not known earlier).
class CrmTrackingBanner extends StatelessWidget {
  const CrmTrackingBanner({super.key, required this.since});
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final day = since == null ? 'recently' : DateFormat('d MMM yyyy').format(since!);
    return Container(
      key: const Key('crmTrackingBanner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: crm.warning.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.warning.withValues(alpha: 0.35))),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: crm.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The CRM records began on $day. Who owned and decided the work is known only from then — earlier figures show "—", not 0.',
              style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── the work ────────────────────────────────────────────────────────────────

IconData crmTypeIcon(String type) => switch (type) {
  'booking' => Icons.receipt_long_outlined,
  'conversation' => Icons.forum_outlined,
  'case' => Icons.report_problem_outlined,
  'trial' => Icons.event_available_outlined,
  _ => Icons.work_outline,
};

/// Owner chip: the person's name, or "Unassigned" in amber.
class CrmOwnerChip extends StatelessWidget {
  const CrmOwnerChip({super.key, required this.name, this.assigned = true});
  final String name;
  final bool assigned;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final color = assigned ? crm.primary : crm.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(assigned ? Icons.person_outline : Icons.person_off_outlined, size: 13, color: color),
          const SizedBox(width: 4),
          Text(assigned ? (name.isEmpty ? 'Assigned' : name) : 'Unassigned', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// A list of open work. With [selected] + [onToggle], rows can be ticked (the head hands several out at once); [onTake] shows a
/// "Take it" button on unassigned rows (a member claims work).
class CrmQueueList extends StatelessWidget {
  const CrmQueueList({super.key, required this.items, this.selected, this.onToggle, this.onTake, this.emptyText = 'Nothing waiting.', this.now});
  final List<CrmQueueItem> items;
  final Set<String>? selected;
  final void Function(CrmQueueItem item)? onToggle;
  final void Function(CrmQueueItem item)? onTake;
  final String emptyText;
  final DateTime? now;

  static String keyOf(CrmQueueItem i) => '${i.type}:${i.id}';

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, size: 36, color: crm.success),
              const SizedBox(height: 8),
              Text(emptyText, key: const Key('crmQueueEmpty'), style: TextStyle(color: crm.textSecondary)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final i in items)
          CrmPanel(
            key: Key('crmQueueItem_${keyOf(i)}'),
            margin: const EdgeInsets.only(bottom: 8),
            radius: 12,
            borderColor: i.overdue ? crm.destructive.withValues(alpha: 0.45) : null,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: i.link.isEmpty ? null : () => context.go(i.link),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    if (selected != null && onToggle != null)
                      Checkbox(key: Key('crmQueueCheck_${keyOf(i)}'), value: selected!.contains(keyOf(i)), onChanged: (_) => onToggle!(i))
                    else
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(crmTypeIcon(i.type), size: 20, color: crm.textSecondary)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            [i.typeLabel, if (i.subtitle.isNotEmpty) i.subtitle].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: crm.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              CrmOwnerChip(name: i.ownerName, assigned: i.isAssigned),
                              if (i.dueAt != null)
                                Text(crmDueText(i.dueAt, now: now), style: TextStyle(fontSize: 11.5, fontWeight: i.overdue ? FontWeight.w700 : FontWeight.w500, color: i.overdue ? crm.destructive : crm.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (onTake != null && !i.isAssigned)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: OutlinedButton(key: Key('crmTake_${keyOf(i)}'), onPressed: () => onTake!(i), child: const Text('Take it')),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The head picks who gets the work (or "Unassigned" to take it back). → the owner id, '' for unassigned, or null when cancelled.
Future<String?> showCrmAssignDialog(BuildContext context, {required int count, String title = 'Assign to'}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final team = ref.watch(crmTeamProvider);
        return AlertDialog(
          title: Text('$title${count > 1 ? ' ($count)' : ''}'),
          content: SizedBox(
            width: 380,
            child: team.when(
              loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text(friendlyErrorMessage(e)),
              data: (t) => ListView(
                shrinkWrap: true,
                children: [
                  for (final m in t.members)
                    ListTile(
                      key: Key('crmAssignTo_${m.userId}'),
                      leading: CircleAvatar(child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase())),
                      title: Text('${m.name}${m.isHead ? ' (Head)' : ''}'),
                      subtitle: Text('${m.workload.total} open · ${m.workload.overdue} overdue'),
                      onTap: () => Navigator.pop(ctx, m.userId),
                    ),
                  const Divider(),
                  ListTile(
                    key: const Key('crmAssignTo_none'),
                    leading: const Icon(Icons.person_off_outlined),
                    title: const Text('Unassigned'),
                    subtitle: const Text('Take it back from whoever has it'),
                    onTap: () => Navigator.pop(ctx, ''),
                  ),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
        );
      },
    ),
  );
}

/// Assigns [items] to [ownerId] ('' = unassigned) and says what happened.
Future<bool> crmAssign(BuildContext context, WidgetRef ref, List<CrmQueueItem> items, String ownerId) async {
  try {
    final r = await ref.read(crmServiceProvider).assign([for (final i in items) (type: i.type, id: i.id)], ownerId.isEmpty ? null : ownerId);
    refreshCrm(ref);
    if (!context.mounted) return true;
    final skipped = r.skippedReasons.toSet();
    showSuccessSnackBar(context, '${r.assigned} assigned${skipped.isEmpty ? '' : ' · not done: ${skipped.join(' ')}'}');
    return true;
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
    return false;
  }
}

// ── the report ──────────────────────────────────────────────────────────────

/// Asks which dates and which file (Excel / PDF), then downloads the CRM report — the team's, or [memberId]'s.
Future<void> downloadCrmReport(BuildContext context, WidgetRef ref, {required ReportRange initial, String? memberId, String who = 'the team'}) async {
  final range = await showReportRangeDialog(
    context,
    title: 'CRM report — which dates?',
    subtitle: 'For $who. The Excel file has every request, chat, review, case, trial and call behind the figures; the PDF is the summary.',
    confirmLabel: 'Next',
    initial: initial,
    maxDays: kCrmMaxDays,
  );
  if (range == null || !context.mounted) return;
  final format = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Download as'),
      children: [
        SimpleDialogOption(key: const Key('crmReportXlsx'), onPressed: () => Navigator.pop(ctx, 'xlsx'), child: const ListTile(leading: Icon(Icons.table_chart_outlined), title: Text('Excel'), subtitle: Text('Everything, one sheet per kind of work'))),
        SimpleDialogOption(key: const Key('crmReportPdf'), onPressed: () => Navigator.pop(ctx, 'pdf'), child: const ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text('PDF'), subtitle: Text('The summary, the team, what is overdue and the cases'))),
      ],
    ),
  );
  if (format == null || !context.mounted) return;
  try {
    final (name, bytes) = await ref.read(crmServiceProvider).downloadReport(range, format: format, memberId: memberId);
    await saveFileBytes(name, bytes, mime: format == 'pdf' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    if (context.mounted) showSuccessSnackBar(context, 'Downloaded $name');
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

/// A white card with a border that list rows and taps can sit in: it IS the Material they paint their ink on (a coloured box between
/// a ListTile and its Material hides the ink, and Flutter warns "ListTile background color or ink splashes may be invisible").
class CrmPanel extends StatelessWidget {
  const CrmPanel({super.key, required this.child, this.padding = EdgeInsets.zero, this.margin = EdgeInsets.zero, this.radius = 14, this.borderColor});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Padding(
      padding: margin,
      child: Material(
        color: crm.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: borderColor ?? crm.border)),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
