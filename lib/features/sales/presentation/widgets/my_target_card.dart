import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/sales/data/sales_target.dart';
import 'package:nizan_crm/features/sales/services/sales_target_service.dart';

String targetRupees(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

String targetRupeesShort(num v) {
  final a = v.abs();
  if (a >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
  if (a >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
  if (a >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
  return '₹${v.toStringAsFixed(0)}';
}

/// Green when on/above target, amber when behind pace, red when far behind.
Color targetStatusColor(double pct, {double expectedPct = 1}) {
  if (pct >= 1) return const Color(0xFF16A34A);
  if (pct >= expectedPct * 0.85) return const Color(0xFF2563EB);
  if (pct >= expectedPct * 0.5) return const Color(0xFFD97706);
  return const Color(0xFFDC2626);
}

/// "My target" for the signed-in salesperson: this month's target vs what
/// they've booked, with pace guidance. Month can be switched.
class MyTargetCard extends ConsumerStatefulWidget {
  const MyTargetCard({super.key});

  @override
  ConsumerState<MyTargetCard> createState() => _MyTargetCardState();
}

class _MyTargetCardState extends ConsumerState<MyTargetCard> {
  late TargetPeriod _period = (month: DateTime.now().month, year: DateTime.now().year);

  void _shift(int delta) {
    final d = DateTime(_period.year, _period.month + delta);
    setState(() => _period = (month: d.month, year: d.year));
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(myTargetProvider(_period));
    final now = DateTime.now();
    final isCurrent = _period.month == now.month && _period.year == now.year;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crm.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.flag_rounded, size: 18, color: crm.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('My target',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            ),
            IconButton(
              tooltip: 'Previous month',
              visualDensity: VisualDensity.compact,
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(DateFormat('MMM yyyy').format(DateTime(_period.year, _period.month)),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            IconButton(
              tooltip: 'Next month',
              visualDensity: VisualDensity.compact,
              onPressed: isCurrent ? null : () => _shift(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
          const SizedBox(height: 6),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppErrorView(
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(myTargetProvider(_period)),
            ),
            data: (p) => _Body(p: p),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final MyTargetProgress p;
  const _Body({required this.p});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final t = p.target;
    final a = p.achieved;

    if (t == null || t.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: crm.input, borderRadius: BorderRadius.circular(12)),
          child: Text(
              t?.derived ?? false
                  ? 'No salesperson targets set for this month yet — your target is the total of theirs (Sales Targets).'
                  : 'No target set for this month yet. Your manager sets it in Sales Targets.',
              style: TextStyle(fontSize: 13, color: crm.textSecondary)),
        ),
        const SizedBox(height: 12),
        Text('Booked so far: ${targetRupees(a.salesValue)} · ${a.bookings} booking${a.bookings == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: crm.textPrimary)),
      ]);
    }

    final elapsed = p.daysInMonth == 0 ? 1.0 : (p.daysInMonth - p.daysLeft) / p.daysInMonth;
    final expected = p.daysLeft == 0 ? 1.0 : max(elapsed, 0.0);
    final valuePct = t.salesTarget > 0 ? a.salesValue / t.salesTarget : null;
    final countPct = t.bookingsTarget > 0 ? a.bookings / t.bookingsTarget : null;
    final mainPct = valuePct ?? countPct ?? 0;
    final color = targetStatusColor(mainPct, expectedPct: expected);
    final remaining = max(0.0, t.salesTarget - a.salesValue);
    final perDay = p.daysLeft > 0 ? remaining / p.daysLeft : 0.0;

    final ring = SizedBox(
      width: 112,
      height: 112,
      child: Stack(fit: StackFit.expand, children: [
        CircularProgressIndicator(
          value: mainPct.clamp(0, 1).toDouble(),
          strokeWidth: 10,
          strokeCap: StrokeCap.round,
          backgroundColor: color.withValues(alpha: 0.12),
          color: color,
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${(mainPct * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: crm.textPrimary)),
            Text('achieved', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ]),
        ),
      ]),
    );

    String status;
    if (mainPct >= 1) {
      status = 'Target achieved — great work! 🎉';
    } else if (p.daysLeft == 0) {
      status = 'Month closed at ${(mainPct * 100).toStringAsFixed(0)}% of target.';
    } else if (mainPct >= expected * 0.85) {
      status = 'On track for this month.';
    } else {
      status = 'Behind pace — ${(expected * 100).toStringAsFixed(0)}% of the month has gone.';
    }

    final details = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (t.salesTarget > 0) ...[
        Text('Sales value', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: targetRupees(a.salesValue),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            TextSpan(text: '  of ${targetRupees(t.salesTarget)}', style: TextStyle(fontSize: 13, color: crm.textSecondary)),
          ]),
        ),
        const SizedBox(height: 8),
      ],
      if (t.bookingsTarget > 0) ...[
        Text('Bookings', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        Row(children: [
          Text('${a.bookings} / ${t.bookingsTarget}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (countPct ?? 0).clamp(0, 1).toDouble(),
                minHeight: 6,
                backgroundColor: crm.input,
                color: targetStatusColor(countPct ?? 0, expectedPct: expected),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
      ],
      Text(status, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
    ]);

    final facts = <(IconData, String, String)>[
      if (t.salesTarget > 0) (Icons.trending_up_rounded, 'Still to book', remaining > 0 ? targetRupees(remaining) : 'Done'),
      (Icons.calendar_today_rounded, 'Days left', '${p.daysLeft}'),
      if (t.salesTarget > 0 && p.daysLeft > 0 && remaining > 0)
        (Icons.speed_rounded, 'Needed per day', targetRupeesShort(perDay)),
    ];

    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 420;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (narrow) ...[
          Center(child: ring),
          const SizedBox(height: 12),
          details,
        ] else
          Row(children: [ring, const SizedBox(width: 20), Expanded(child: details)]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (icon, label, value) in facts)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: crm.input, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 15, color: crm.primary),
                const SizedBox(width: 6),
                Text('$label: ', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              ]),
            ),
        ]),
        if (a.daily.any((v) => v > 0)) ...[
          const SizedBox(height: 14),
          Text('Booked each day', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          const SizedBox(height: 6),
          _DailyBars(daily: a.daily, color: crm.primary),
        ],
        if (t.derived) ...[
          const SizedBox(height: 10),
          Text(
            'Team target: the total of ${t.teamSize} salesperson${t.teamSize == 1 ? '' : 's'}’ targets. '
            'Achieved = the team’s sales${(p.own?.salesValue ?? 0) > 0 ? ' plus your own ${targetRupees(p.own!.salesValue)}' : ' plus your own'}.',
            style: TextStyle(fontSize: 12, color: crm.textSecondary),
          ),
        ],
        if (t.note.isNotEmpty || t.setByName.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            [
              if (t.note.isNotEmpty) '“${t.note}”',
              if (t.setByName.isNotEmpty) 'Set by ${t.setByName}',
            ].join(' — '),
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: crm.textSecondary),
          ),
        ],
      ]);
    });
  }
}

class _DailyBars extends StatelessWidget {
  final List<double> daily;
  final Color color;
  const _DailyBars({required this.daily, required this.color});

  @override
  Widget build(BuildContext context) {
    final top = daily.fold<double>(0, max);
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < daily.length; i++)
            Expanded(
              child: Tooltip(
                message: 'Day ${i + 1}: ${targetRupees(daily[i])}',
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: top == 0 ? 2 : max(2, 44 * daily[i] / top),
                  decoration: BoxDecoration(
                    color: daily[i] > 0 ? color : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
