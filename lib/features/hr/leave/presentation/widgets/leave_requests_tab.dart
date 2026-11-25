// Requests (leave desk): every employee's leave for the year with filters,
// search and the per-request actions (approve, reject, cancel, re-send).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/app_error_view.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/leave/data/leave_models.dart';
import 'package:nizan_crm/features/hr/leave/presentation/widgets/leave_common.dart';
import 'package:nizan_crm/features/hr/leave/service/leave_service.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';

const _statuses = ['all', 'pending', 'approved', 'rejected', 'cancelled'];

class LeaveRequestsTab extends ConsumerStatefulWidget {
  const LeaveRequestsTab({super.key, required this.ownEmployeeId, required this.isAdmin});
  final String ownEmployeeId;
  final bool isAdmin;
  @override
  ConsumerState<LeaveRequestsTab> createState() => _LeaveRequestsTabState();
}

class _LeaveRequestsTabState extends ConsumerState<LeaveRequestsTab> {
  String _status = 'pending';
  String _type = 'all';
  String _dept = 'all';
  String _source = 'all';
  int _month = 0; // 0 = whole year
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(LeaveRequest r, {bool ignoreStatus = false}) {
    if (!ignoreStatus && _status != 'all' && r.status != _status) return false;
    if (_type != 'all' && r.leaveTypeName != _type) return false;
    if (_dept != 'all' && r.department != _dept) return false;
    if (_source == 'timebox' && !r.fromTimebox) return false;
    if (_source == 'crm' && r.fromTimebox) return false;
    if (_month != 0) {
      final y = ref.read(leaveYearProvider);
      final start = DateTime(y, _month, 1);
      final end = DateTime(y, _month + 1, 0);
      if (!leaveOverlaps(r, start, end)) return false;
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      if (!r.employeeName.toLowerCase().contains(q) &&
          !r.reason.toLowerCase().contains(q) &&
          !r.department.toLowerCase().contains(q)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final reqs = ref.watch(leaveRequestsProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshLeaveData(ref, desk: true),
      child: reqs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(leaveRequestsProvider))]),
        data: (all) {
          final types = all.map((r) => r.leaveTypeName).where((s) => s.isNotEmpty).toSet().toList()..sort();
          final depts = all.map((r) => r.department).where((s) => s.isNotEmpty).toSet().toList()..sort();
          final counts = {
            for (final s in _statuses)
              s: all.where((r) => _matches(r, ignoreStatus: true) && (s == 'all' || r.status == s)).length,
          };
          final list = all.where((r) => _matches(r)).toList()
            ..sort((a, b) {
              if (_status == 'pending' || _status == 'all') {
                final ap = a.status == 'pending' ? 0 : 1;
                final bp = b.status == 'pending' ? 0 : 1;
                if (ap != bp) return ap - bp;
              }
              return (b.fromDate ?? DateTime(0)).compareTo(a.fromDate ?? DateTime(0));
            });
          final totalDays = list.where((r) => r.status == 'approved').fold<double>(0, (s, r) => s + r.days);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Status segments with counts
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statuses
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('${s == 'all' ? 'All' : leaveStatusLabel(s)} ${counts[s]}'),
                              selected: _status == s,
                              onSelected: (_) => setState(() => _status = s),
                              selectedColor: (s == 'all' ? crm.primary : leaveStatusColor(s, crm)).withValues(alpha: 0.16),
                              labelStyle: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _status == s
                                    ? (s == 'all' ? crm.primary : leaveStatusColor(s, crm))
                                    : crm.textSecondary,
                              ),
                              side: BorderSide(color: crm.border),
                              showCheckmark: false,
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search name, reason, department',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                _drop('Month', _month, [
                  const DropdownMenuItem(value: 0, child: Text('Whole year')),
                  for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(leaveMonthNames[m])),
                ], (v) => setState(() => _month = v ?? 0)),
                _drop('Type', _type, [
                  const DropdownMenuItem(value: 'all', child: Text('All types')),
                  ...types.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                ], (v) => setState(() => _type = v ?? 'all')),
                _drop('Department', _dept, [
                  const DropdownMenuItem(value: 'all', child: Text('All departments')),
                  ...depts.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                ], (v) => setState(() => _dept = v ?? 'all')),
                _drop('Source', _source, const [
                  DropdownMenuItem(value: 'all', child: Text('All sources')),
                  DropdownMenuItem(value: 'timebox', child: Text('Timebox only')),
                  DropdownMenuItem(value: 'crm', child: Text('CRM only')),
                ], (v) => setState(() => _source = v ?? 'all')),
              ]),
              const SizedBox(height: 12),
              Text(
                '${list.length} request${list.length == 1 ? '' : 's'}'
                '${totalDays > 0 ? ' · ${leaveNum(totalDays)} approved day${totalDays == 1 ? '' : 's'}' : ''}',
                style: TextStyle(fontSize: 12, color: crm.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: hrCardDecoration(crm),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: list.isEmpty
                    ? const LeaveEmpty(icon: Icons.inbox_outlined, title: 'No requests match', body: 'Change the filters above.')
                    : Column(
                        children: [
                          for (var i = 0; i < list.length; i++)
                            _RequestRow(
                              r: list[i],
                              first: i == 0,
                              own: !widget.isAdmin &&
                                  widget.ownEmployeeId.isNotEmpty &&
                                  list[i].employeeId == widget.ownEmployeeId,
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _drop<T>(String label, T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
    final has = items.any((i) => i.value == value);
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<T>(
        key: ValueKey('$label-$value-${items.length}'),
        initialValue: has ? value : items.first.value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _RequestRow extends ConsumerStatefulWidget {
  const _RequestRow({required this.r, required this.first, required this.own});
  final LeaveRequest r;
  final bool first;
  final bool own;
  @override
  ConsumerState<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends ConsumerState<_RequestRow> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    await f();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = widget.r;

    final actions = <Widget>[
      if (r.status == 'pending' && !widget.own) ...[
        _btn('Reject', crm.destructive, () => _run(() => decideLeave(context, ref, r, approve: false))),
        FilledButton(
          onPressed: () => _run(() => decideLeave(context, ref, r, approve: true)),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          child: const Text('Approve'),
        ),
      ],
      if (r.status == 'approved' && !widget.own)
        _btn('Cancel leave', crm.destructive, () => _run(() => cancelLeaveRequest(context, ref, r, desk: true))),
      // Timebox update failed, or a decision was never sent.
      if (r.fromTimebox &&
          r.status != 'pending' &&
          (r.callbackStatus == 'failed' || (r.callbackStatus == 'none' && r.status != 'cancelled')))
        _btn(r.callbackStatus == 'failed' ? 'Re-send to Timebox' : 'Send to Timebox', crm.primary,
            () => _run(() => resendToTimebox(context, ref, r))),
    ];

    final decided = r.status != 'pending' && r.decidedAt != null
        ? '${leaveStatusLabel(r.status)} ${leaveFmtShort(r.decidedAt)}${r.decisionNote.isNotEmpty ? ' — ${r.decisionNote}' : ''}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: widget.first ? null : Border(top: BorderSide(color: crm.border))),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final who = Row(children: [
          LeaveAvatar(r.employeeName, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.employeeName.isEmpty ? 'Employee' : r.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              Text(r.department.isEmpty ? '—' : r.department,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ]),
          ),
        ]);
        final what = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(
              '${r.leaveTypeName.isEmpty ? 'Leave' : r.leaveTypeName} · ${leaveRange(r.fromDate, r.toDate)} · ${leaveDays(r.days)}'
              '${r.halfDay != 'none' ? ' (${r.halfDay} half)' : ''}',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary),
            ),
            LeaveSourceTag(r),
          ]),
          if (r.reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('"${r.reason}"',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ),
          if (decided.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(decided,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: crm.textSecondary)),
            ),
          if (widget.own && r.status == 'pending')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Your own request — another HR user or admin decides',
                  style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: crm.textSecondary)),
            ),
        ]);
        final right = Row(mainAxisSize: MainAxisSize.min, children: [
          leaveStatusChip(r.status, crm),
          if (_busy) ...[
            const SizedBox(width: 12),
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ] else
            for (final a in actions) ...[const SizedBox(width: 8), a],
        ]);

        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(width: 210, child: who),
            const SizedBox(width: 12),
            Expanded(child: what),
            const SizedBox(width: 12),
            right,
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          who,
          const SizedBox(height: 6),
          what,
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: right)),
        ]);
      }),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(label),
      );
}
