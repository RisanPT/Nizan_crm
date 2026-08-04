import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/space_extension.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../data/timebox_models.dart';
import '../../service/timebox_service.dart';
import 'attendance_summary_screen.dart' show attendanceColor;
import 'attendance_detail_screen.dart';

const _months = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

/// Accounts: attendance-driven administrative payroll.
/// Base salary is pro-rated by each employee's Timebox attendance for the month.
class AttendancePayrollScreen extends HookConsumerWidget {
  const AttendancePayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final month = ref.watch(timeboxMonthProvider);
    final previewAsync = ref.watch(payrollPreviewProvider);
    final busy = useState(false);
    final syncing = useState(false);

    Future<void> doSync() async {
      syncing.value = true;
      try {
        final result = await ref.read(timeboxServiceProvider).syncEmployees();
        ref.invalidate(payrollPreviewProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: result.unmatched > 0 ? crm.warning : crm.success,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: crm.destructive),
          );
        }
      } finally {
        syncing.value = false;
      }
    }

    Future<void> generate(PayrollPreview preview) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Generate salary slips?'),
          content: Text(
            'This will create/update administrative salary slips for '
            '${_months[month.month]} ${month.year}, pro-rated by attendance.\n\n'
            '• ${preview.matched} employees will get slips\n'
            '• ${preview.unmatched} unmatched (no CRM link) will be skipped\n'
            '• Total net payable: ${_money(preview.totalNetPayable)}\n\n'
            'Slips already marked "paid" are never changed.\n'
            'Tip: Run "Sync Timebox → CRM" first to maximise matched employees.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate')),
          ],
        ),
      );
      if (ok != true) return;
      busy.value = true;
      try {
        final msg = await ref
            .read(timeboxServiceProvider)
            .generatePayroll(from: month.from, to: month.to);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: crm.success),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: crm.destructive),
          );
        }
      } finally {
        busy.value = false;
      }
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Attendance Payroll'),
        backgroundColor: crm.sidebar,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ── Sync Timebox → CRM ──
          Tooltip(
            message: 'Sync Timebox employees → CRM (establishes ID bindings for stable matching)',
            child: syncing.value
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.sync_alt),
                    onPressed: doSync,
                  ),
          ),
          IconButton(
            tooltip: 'Refresh payroll preview',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(payrollPreviewProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Month navigation bar ──
          _MonthBar(month: month, crm: crm, ref: ref),
          const Divider(height: 1),
          Expanded(
            child: previewAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_off_outlined, size: 48, color: crm.destructive),
                    12.h,
                    Text('$e', textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
                    16.h,
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(payrollPreviewProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ]),
                ),
              ),
              data: (preview) => Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      children: [
                        _TotalsCard(preview: preview, crm: crm),
                        12.h,
                        if (preview.unmatched > 0)
                          _UnmatchedNote(count: preview.unmatched, crm: crm),
                        if (preview.unmatched > 0) 10.h,
                        ...preview.rows.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _PayrollCard(
                                row: r,
                                crm: crm,
                                onTapAttendance: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AttendanceDetailScreen(
                                        employeeId: r.timeboxId,
                                        employeeName: r.name,
                                        department: r.department,
                                        attendancePercent: r.attendancePercent,
                                        daysPresent: r.daysPresent,
                                        expectedDays: r.expectedDays,
                                        hoursWorked: r.hoursWorked,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )),
                      ],
                    ),
                  ),
                  _GenerateBar(
                    preview: preview,
                    busy: busy.value,
                    crm: crm,
                    onGenerate: () => generate(preview),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Month navigation bar ─────────────────────────────────────────────────────

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, required this.crm, required this.ref});
  final TimeboxMonth month;
  final CrmTheme crm;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                ref.read(timeboxMonthProvider.notifier).state = month.prev,
          ),
          Expanded(
            child: Center(
              child: Text('${_months[month.month]} ${month.year}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: crm.accent, fontSize: 15)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                ref.read(timeboxMonthProvider.notifier).state = month.next,
          ),
        ],
      ),
    );
  }
}

// ── Totals card ───────────────────────────────────────────────────────────────

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.preview, required this.crm});
  final PayrollPreview preview;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 18, color: crm.accent),
              8.w,
              Text('Payable (attendance pro-rated)',
                  style: TextStyle(fontWeight: FontWeight.w700, color: crm.textSecondary, fontSize: 12.5)),
            ],
          ),
          10.h,
          Text(_money(preview.totalNetPayable),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: crm.accent)),
          10.h,
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill('Full base', _money(preview.totalBase), crm.textSecondary, crm),
            _pill('Absence cut', '- ${_money(preview.totalAbsenceDeduction)}', crm.destructive, crm),
            _pill('Matched', '${preview.matched}', crm.success, crm),
            if (preview.unmatched > 0)
              _pill('Unmatched', '${preview.unmatched}', crm.warning, crm),
          ]),
        ],
      ),
    );
  }

  Widget _pill(String k, String v, Color c, CrmTheme crm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$k: ', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        Text(v, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}

// ── Unmatched warning ─────────────────────────────────────────────────────────

class _UnmatchedNote extends StatelessWidget {
  const _UnmatchedNote({required this.count, required this.crm});
  final int count;
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.warning.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.link_off, size: 18, color: crm.warning),
        10.w,
        Expanded(
          child: Text(
            '$count Timebox employees could not be linked to a CRM staff record. '
            'Tap "Sync Timebox → CRM" (↺ icon) to establish ID bindings, then refresh.',
            style: TextStyle(fontSize: 12, color: crm.textSecondary),
          ),
        ),
      ]),
    );
  }
}

// ── Match confidence badge ────────────────────────────────────────────────────

/// Returns (color, label, icon) for a matchedBy value.
(Color, String, IconData) _matchBadge(String matchedBy, CrmTheme crm) {
  switch (matchedBy) {
    case 'id':
      return (crm.success, 'ID', Icons.link);
    case 'email':
      return (crm.success, 'Email', Icons.email_outlined);
    case 'name':
      return (crm.warning, 'Name', Icons.person_outline);
    default:
      return (crm.destructive, 'None', Icons.link_off);
  }
}

// ── Payroll card ──────────────────────────────────────────────────────────────

class _PayrollCard extends StatelessWidget {
  const _PayrollCard({
    required this.row,
    required this.crm,
    required this.onTapAttendance,
  });
  final PayrollRow row;
  final CrmTheme crm;
  final VoidCallback onTapAttendance;

  @override
  Widget build(BuildContext context) {
    final attColor = attendanceColor(row.attendancePercent, crm);
    final (matchColor, matchLabel, matchIcon) = _matchBadge(row.matchedBy, crm);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: row.matched ? crm.border : crm.warning.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name.trim().isEmpty ? 'Unknown' : row.name.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    2.h,
                    Text(row.department,
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  ],
                ),
              ),
              8.w,
              // Match confidence badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: matchColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: matchColor.withValues(alpha: 0.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(matchIcon, size: 11, color: matchColor),
                  4.w,
                  Text('Match: $matchLabel',
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w700, color: matchColor)),
                ]),
              ),
              8.w,
              // Attendance chip — tappable to drill into detail
              GestureDetector(
                onTap: onTapAttendance,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: attColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '${row.attendancePercent}% · ${row.daysPresent}/${row.expectedDays}d',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700, color: attColor),
                    ),
                    4.w,
                    Icon(Icons.chevron_right, size: 13, color: attColor),
                  ]),
                ),
              ),
            ],
          ),
          10.h,
          if (!row.matched)
            Text('No CRM link — base salary unknown',
                style: TextStyle(fontSize: 12, color: crm.warning, fontStyle: FontStyle.italic))
          else
            Row(
              children: [
                Expanded(child: _col('Base', _money(row.baseSalary), crm.textSecondary)),
                Expanded(
                    child: _col(
                        'Absence', '- ${_money(row.absenceDeduction)}', crm.destructive)),
                Expanded(
                    child: _col('Net payable', _money(row.netPayable), crm.accent,
                        bold: true)),
              ],
            ),
          if (row.matchedBy == 'name') ...[
            8.h,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: crm.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, size: 13, color: crm.warning),
                6.w,
                Expanded(
                  child: Text(
                    'Matched by name only — run Sync to lock in a stable ID binding.',
                    style: TextStyle(fontSize: 11, color: crm.warning),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _col(String k, String v, Color c, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: TextStyle(fontSize: 10.5, color: c.withValues(alpha: 0.9))),
        2.h,
        Text(v,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: c)),
      ],
    );
  }
}

// ── Generate bar ──────────────────────────────────────────────────────────────

class _GenerateBar extends StatelessWidget {
  const _GenerateBar({
    required this.preview,
    required this.busy,
    required this.crm,
    required this.onGenerate,
  });
  final PayrollPreview preview;
  final bool busy;
  final CrmTheme crm;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(top: BorderSide(color: crm.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Net payable', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                Text(_money(preview.totalNetPayable),
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: crm.accent)),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: (busy || preview.matched == 0) ? null : onGenerate,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.receipt_long_outlined),
            label: Text(busy ? 'Generating…' : 'Generate slips'),
          ),
        ],
      ),
    );
  }
}
