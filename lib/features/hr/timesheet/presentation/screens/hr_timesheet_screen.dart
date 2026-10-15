import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/hr/timesheet/data/timesheet_models.dart';
import 'package:nizan_crm/features/hr/timesheet/service/timesheet_service.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/hr/approvals/service/approval_service.dart';

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _fmt(DateTime? d) {
  if (d == null) return '';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

DateTime _mondayOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

Color _statusColor(String s, CrmTheme crm) {
  switch (s) {
    case 'approved':
      return crm.success;
    case 'rejected':
      return crm.destructive;
    case 'pending':
      return crm.warning;
    default:
      return crm.textSecondary; // draft
  }
}

Widget _statusChip(String s, CrmTheme crm) =>
    hrStatusChip(s[0].toUpperCase() + s.substring(1), _statusColor(s, crm));

/// HR Time Tracker — employees fill a weekly timesheet and submit it for
/// approval; managers/HR review submitted sheets. Routes through the approval
/// engine.
class HrTimesheetScreen extends ConsumerWidget {
  const HrTimesheetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final access = Access.of(session);
    final hasEmployee = (session?.employeeId ?? '').isNotEmpty;
    final isManager = access.isFullAccess || access.isDepartmentHead || access.has('timesheet', false) || access.has('staff', false);

    final tabs = <Tab>[
      if (hasEmployee) const Tab(text: 'My Timesheet'),
      if (isManager) const Tab(text: 'Submitted'),
    ];
    final views = <Widget>[
      if (hasEmployee) _MyTab(crm: crm),
      if (isManager) _RequestsTab(crm: crm),
    ];
    if (tabs.isEmpty) {
      return Scaffold(
        backgroundColor: crm.background,
        body: Center(child: Text('No employee record is linked to your account.', style: TextStyle(color: crm.textSecondary))),
      );
    }
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: crm.background,
        body: Column(
          children: [
            Material(
              color: crm.surface,
              child: TabBar(
                labelColor: crm.primary,
                unselectedLabelColor: crm.textSecondary,
                indicatorColor: crm.primary,
                tabs: tabs,
              ),
            ),
            Expanded(child: TabBarView(children: views)),
          ],
        ),
      ),
    );
  }
}

class _MyTab extends ConsumerWidget {
  const _MyTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myTimesheetsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('New week'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myTimesheetsProvider),
        child: mine.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(myTimesheetsProvider))]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text('No timesheets yet. Start a new week.', style: TextStyle(color: crm.textSecondary))),
                  )
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: list.map((t) => _row(context, ref, t)).toList(),
                ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Timesheet t) {
    final isDraft = t.status == 'draft';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.periodLabel.isEmpty ? _fmt(t.periodStart) : t.periodLabel,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                Text('${t.totalHours.toStringAsFixed(t.totalHours % 1 == 0 ? 0 : 1)}h · ${t.entries.length} entr${t.entries.length == 1 ? 'y' : 'ies'}',
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                if (t.status == 'rejected' && t.decisionNote.isNotEmpty)
                  Text('Note: ${t.decisionNote}', style: TextStyle(fontSize: 11, color: crm.destructive)),
              ],
            ),
          ),
          _statusChip(t.status, crm),
          if (isDraft) ...[
            IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: crm.textSecondary), onPressed: () => _openEditor(context, ref, t)),
            IconButton(
              tooltip: 'Submit',
              icon: Icon(Icons.send_outlined, size: 18, color: crm.primary),
              onPressed: () async {
                try {
                  await ref.read(timesheetServiceProvider).submit(t.id);
                  ref.invalidate(myTimesheetsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timesheet submitted')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, Timesheet? existing) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _WeekEditor(existing: existing));
    if (ok == true) ref.invalidate(myTimesheetsProvider);
  }
}

class _WeekEditor extends ConsumerStatefulWidget {
  const _WeekEditor({this.existing});
  final Timesheet? existing;
  @override
  ConsumerState<_WeekEditor> createState() => _WeekEditorState();
}

class _WeekEditorState extends ConsumerState<_WeekEditor> {
  late DateTime _monday;
  late List<TextEditingController> _hours;
  late List<TextEditingController> _projects;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _monday = widget.existing?.periodStart != null ? _mondayOf(widget.existing!.periodStart!) : _mondayOf(DateTime.now());
    _hours = List.generate(7, (_) => TextEditingController());
    _projects = List.generate(7, (_) => TextEditingController());
    // Pre-fill from an existing draft's entries by matching the day offset.
    for (final e in widget.existing?.entries ?? const <TimesheetEntry>[]) {
      if (e.date == null) continue;
      final idx = DateTime(e.date!.year, e.date!.month, e.date!.day).difference(_monday).inDays;
      if (idx >= 0 && idx < 7) {
        _hours[idx].text = e.hours == 0 ? '' : e.hours.toString();
        _projects[idx].text = e.project;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _hours) {
      c.dispose();
    }
    for (final c in _projects) {
      c.dispose();
    }
    super.dispose();
  }

  List<TimesheetEntry> _buildEntries() {
    final out = <TimesheetEntry>[];
    for (var i = 0; i < 7; i++) {
      final h = double.tryParse(_hours[i].text.trim()) ?? 0;
      final p = _projects[i].text.trim();
      if (h > 0 || p.isNotEmpty) {
        out.add(TimesheetEntry(date: _monday.add(Duration(days: i)), hours: h, project: p));
      }
    }
    return out;
  }

  Future<void> _save({required bool submit}) async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(timesheetServiceProvider);
      final ts = await svc.save(
        periodStart: _monday,
        periodLabel: 'Week of ${_fmt(_monday)}',
        entries: _buildEntries(),
      );
      if (submit) await svc.submit(ts.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return AlertDialog(
      title: const Text('Weekly timesheet'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Week of ${_fmt(_monday)}', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary))),
                  TextButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                          context: context, initialDate: _monday, firstDate: DateTime(2023), lastDate: DateTime(2030));
                      if (d != null) setState(() => _monday = _mondayOf(d));
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...List.generate(7, (i) {
                final day = _monday.add(Duration(days: i));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_wd[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                            Text('${day.day}', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: _hours[i],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(hintText: 'hrs', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _projects[i],
                          decoration: const InputDecoration(hintText: 'Project / task', isDense: true),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        OutlinedButton(onPressed: _busy ? null : () => _save(submit: false), child: const Text('Save draft')),
        FilledButton(
          onPressed: _busy ? null : () => _save(submit: true),
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit'),
        ),
      ],
    );
  }
}

class _RequestsTab extends ConsumerStatefulWidget {
  const _RequestsTab({required this.crm});
  final CrmTheme crm;

  @override
  ConsumerState<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<_RequestsTab> {
  String? _actingId;

  Future<void> _handleDecision(String approvalId, bool approve) async {
    String note = '';
    if (!approve) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject Timesheet'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
              hintText: 'e.g. Mismatched hours on bridal session',
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      note = ctrl.text.trim();
    }

    setState(() => _actingId = approvalId);
    try {
      if (approve) {
        await ref.read(approvalServiceProvider).approve(approvalId, note: note);
      } else {
        await ref.read(approvalServiceProvider).reject(approvalId, note: note);
      }
      ref.invalidate(timesheetRequestsProvider);
      ref.invalidate(approvalInboxProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Timesheet approved' : 'Timesheet rejected'),
            backgroundColor: approve ? widget.crm.success : widget.crm.destructive,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = widget.crm;
    final reqs = ref.watch(timesheetRequestsProvider);
    final inbox = ref.watch(approvalInboxProvider).value ?? const [];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(timesheetRequestsProvider);
        ref.invalidate(approvalInboxProvider);
      },
      child: reqs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(timesheetRequestsProvider))]),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Submitted timesheets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                      Text('Review and approve submitted hours directly or via inbox', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/hr/approvals'),
                  icon: const Icon(Icons.inbox_outlined, size: 16),
                  label: const Text('Approvals Inbox'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: crm.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Nothing submitted.', style: TextStyle(color: crm.textSecondary))))
            else
              ...list.map((t) {
                String approvalId = t.approvalId;
                if (approvalId.isEmpty) {
                  final m = inbox.where((a) => a.refId == t.id).firstOrNull;
                  if (m != null) approvalId = m.id;
                }
                final isPending = t.status == 'pending';
                final canAct = isPending && approvalId.isNotEmpty;
                final isActing = _actingId == approvalId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: hrCardDecoration(crm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: t.employeeId.isNotEmpty
                                          ? () => context.push('/staff/${t.employeeId}')
                                          : null,
                                      borderRadius: BorderRadius.circular(4),
                                      child: Text(
                                        t.employeeName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: crm.primary,
                                          decoration: TextDecoration.underline,
                                          decorationColor: crm.primary.withValues(alpha: 0.3),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: crm.border.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        t.periodLabel.isEmpty ? _fmt(t.periodStart) : t.periodLabel,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crm.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total logged: ${t.totalHours.toStringAsFixed(t.totalHours % 1 == 0 ? 0 : 1)} hours (${t.entries.length} entries)',
                                  style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          _statusChip(t.status, crm),
                        ],
                      ),
                      if (canAct) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isActing)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            else ...[
                              OutlinedButton.icon(
                                onPressed: () => _handleDecision(approvalId, false),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: crm.destructive,
                                  side: BorderSide(color: crm.destructive.withValues(alpha: 0.5)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () => _handleDecision(approvalId, true),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Approve'),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: crm.success,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
