import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/finance/data/tax_filing.dart';
import 'package:nizan_crm/features/finance/services/tax_filing_service.dart';

/// Finance → GST/TDS Filings: a statutory-filing calendar (GSTR-1, GSTR-3B, TDS
/// payment, TDS return) with due dates + filed/overdue/pending status.
class TaxFilingsScreen extends ConsumerStatefulWidget {
  const TaxFilingsScreen({super.key});

  @override
  ConsumerState<TaxFilingsScreen> createState() => _TaxFilingsScreenState();
}

class _TaxFilingsScreenState extends ConsumerState<TaxFilingsScreen> {
  late int _month = DateTime.now().month;
  late int _year = DateTime.now().year;

  static const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
      'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  void _shift(int delta) {
    setState(() {
      var m = _month + delta;
      if (m < 1) {
        m = 12;
        _year--;
      } else if (m > 12) {
        m = 1;
        _year++;
      }
      _month = m;
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(taxFilingBoardProvider((month: _month, year: _year)));

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(taxFilingBoardProvider((month: _month, year: _year))),
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
                      Text('GST / TDS Filings',
                          style: TextStyle(
                              fontSize: isMobile ? 21 : 26,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      Text('Statutory filing calendar & status',
                          style: TextStyle(
                              fontSize: 12.5, color: crm.textSecondary)),
                    ],
                  ),
                ),
                _periodPicker(crm),
              ],
            ),
            16.h,
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => AppErrorView(
                error: e,
                onRetry: () => ref.invalidate(
                    taxFilingBoardProvider((month: _month, year: _year))),
              ),
              data: (board) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _summary(crm, 'Overdue', '${board.summaryOverdue}',
                          const Color(0xFFDC2626)),
                      10.w,
                      _summary(crm, 'Pending', '${board.summaryPending}',
                          const Color(0xFFF59E0B)),
                      10.w,
                      _summary(crm, 'Filed', '${board.summaryFiled}',
                          const Color(0xFF16A34A)),
                    ],
                  ),
                  18.h,
                  Text('FOR ${_mon[_month].toUpperCase()} $_year',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: crm.textSecondary)),
                  8.h,
                  for (final f in board.filings) _filingCard(crm, f),
                  if (board.overdue.isNotEmpty) ...[
                    20.h,
                    Text('OVERDUE (EARLIER PERIODS)',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: const Color(0xFFDC2626))),
                    8.h,
                    for (final f in board.overdue) _filingCard(crm, f),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filingCard(CrmTheme crm, TaxFiling f) {
    final color = _statusColor(f.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: crm.textPrimary)),
                    2.h,
                    Text(
                        '${_mon[f.periodMonth]} ${f.periodYear}'
                        '${f.dueDate != null ? '  •  due ${DateFormat('d MMM').format(f.dueDate!)}' : ''}',
                        style: TextStyle(
                            fontSize: 11.5, color: crm.textSecondary)),
                  ],
                ),
              ),
              _pill(_statusLabel(f.status), color),
            ],
          ),
          if (f.amount != null && f.amount! > 0 || f.isFiled) ...[
            8.h,
            Row(
              children: [
                if (f.amount != null && f.amount! > 0)
                  Text('₹${_money(f.amount!)}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary)),
                if (f.isFiled && f.arn.isNotEmpty) ...[
                  10.w,
                  Flexible(
                    child: Text('ARN ${f.arn}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: crm.textSecondary)),
                  ),
                ],
                if (f.isFiled && f.filedDate != null) ...[
                  const Spacer(),
                  Text('filed ${DateFormat('d MMM').format(f.filedDate!)}',
                      style: TextStyle(
                          fontSize: 11, color: const Color(0xFF16A34A))),
                ],
              ],
            ),
          ],
          8.h,
          Align(
            alignment: Alignment.centerRight,
            child: f.isFiled
                ? TextButton.icon(
                    onPressed: () => _markDialog(f, reopen: true),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  )
                : FilledButton.icon(
                    onPressed: () => _markDialog(f),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Mark filed'),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _markDialog(TaxFiling f, {bool reopen = false}) async {
    final arnCtrl = TextEditingController(text: f.arn);
    final amountCtrl = TextEditingController(
        text: (f.amount ?? 0) > 0 ? (f.amount!).toStringAsFixed(0) : '');
    final notesCtrl = TextEditingController(text: f.notes);
    DateTime filedDate = f.filedDate ?? DateTime.now();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: Text('${f.label} — ${_mon[f.periodMonth]} ${f.periodYear}'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: filedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setLocal(() => filedDate = picked);
                    },
                    icon: const Icon(Icons.event, size: 16),
                    label: Text('Filed on ${DateFormat('d MMM y').format(filedDate)}'),
                  ),
                  12.h,
                  TextField(
                    controller: arnCtrl,
                    decoration: const InputDecoration(
                        labelText: 'ARN / acknowledgement no.',
                        border: OutlineInputBorder()),
                  ),
                  12.h,
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Amount paid (₹)', border: OutlineInputBorder()),
                  ),
                  12.h,
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Notes (optional)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (reopen)
              TextButton(
                onPressed: saving ? null : () => _save(ctx, f, status: 'pending'),
                child: const Text('Reset to pending',
                    style: TextStyle(color: Color(0xFFDC2626))),
              ),
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setLocal(() => saving = true);
                      final ok = await _save(ctx, f,
                          status: 'filed',
                          filedDate: filedDate,
                          arn: arnCtrl.text.trim(),
                          amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
                          notes: notesCtrl.text.trim());
                      // Re-enable the button after a failed save.
                      if (!ok && ctx.mounted) setLocal(() => saving = false);
                    },
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        );
      }),
    );
  }

  Future<bool> _save(BuildContext ctx, TaxFiling f,
      {required String status,
      DateTime? filedDate,
      String arn = '',
      double amount = 0,
      String notes = ''}) async {
    try {
      await ref.read(taxFilingServiceProvider).save(
            type: f.type,
            periodMonth: f.periodMonth,
            periodYear: f.periodYear,
            status: status,
            filedDate: filedDate,
            arn: arn,
            amount: amount,
            notes: notes,
          );
      ref.refreshData.taxFilings();
      if (ctx.mounted) Navigator.pop(ctx);
      return true;
    } catch (e) {
      if (ctx.mounted) {
        showErrorSnackBar(ctx, e);
      }
      return false;
    }
  }

  Widget _periodPicker(CrmTheme crm) => Container(
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
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left)),
            Text('${_mon[_month]} $_year',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: crm.textPrimary)),
            IconButton(
                iconSize: 18,
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right)),
          ],
        ),
      );

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
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: color)),
              Text(label,
                  style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            ],
          ),
        ),
      );

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100)),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );

  static Color _statusColor(String s) => switch (s) {
        'filed' => const Color(0xFF16A34A),
        'overdue' => const Color(0xFFDC2626),
        _ => const Color(0xFFF59E0B),
      };
  static String _statusLabel(String s) => switch (s) {
        'filed' => 'Filed',
        'overdue' => 'Overdue',
        _ => 'Pending',
      };

  static String _money(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

extension _Gap on num {
  Widget get h => SizedBox(height: toDouble());
  Widget get w => SizedBox(width: toDouble());
}
