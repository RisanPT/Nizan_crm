import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/sales/data/sales_overview.dart';

// Building blocks of the redesigned Sales Dashboard
// (sales_dashboard_screen.dart). Pure widgets over [SalesOverview].

const _cCount = Color(0xFF6366F1); // team count
const _cSaved = Color(0xFF10B981); // leads saved / good
const _cValue = Color(0xFF0EA5E9); // order value

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// ₹ with lakh / crore shorthand for big numbers.
String money(double v) {
  if (v.abs() >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
  if (v.abs() >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
  return _inr.format(v);
}

String fullMoney(double v) => _inr.format(v);

/// "10 Nov 2026" or "1 – 10 Nov 2026".
String rangeLabel(String from, String to) {
  final a = DateTime.tryParse(from);
  final b = DateTime.tryParse(to);
  if (a == null || b == null) return '';
  if (from == to) return DateFormat('EEE, d MMM yyyy').format(a);
  if (a.year == b.year && a.month == b.month) return '${a.day} – ${DateFormat('d MMM yyyy').format(b)}';
  if (a.year == b.year) return '${DateFormat('d MMM').format(a)} – ${DateFormat('d MMM yyyy').format(b)}';
  return '${DateFormat('d MMM yyyy').format(a)} – ${DateFormat('d MMM yyyy').format(b)}';
}

class DashCard extends StatelessWidget {
  const DashCard({super.key, required this.child, this.title, this.subtitle, this.trailing, this.padding});
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                      if (subtitle != null)
                        Text(subtitle!, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

// ── Alert strip ─────────────────────────────────────────────────────────────

/// Only what needs action: enquiries not saved as leads, overdue
/// follow-ups, and whether today's team count is in.
class AlertStrip extends StatelessWidget {
  const AlertStrip({
    super.key,
    required this.data,
    required this.isToday,
    required this.canEnterCount,
    required this.onShowSources,
  });
  final SalesOverview data;
  final bool isToday;
  final bool canEnterCount;
  final VoidCallback onShowSources;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final pills = <Widget>[];

    Widget pill(IconData icon, String text, Color color, {VoidCallback? onTap, String? action}) => Material(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(text,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                  ),
                  if (action != null) ...[
                    const SizedBox(width: 8),
                    Text(action,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                            decoration: TextDecoration.underline,
                            decorationColor: color)),
                  ],
                ],
              ),
            ),
          ),
        );

    if (data.alertNotSaved > 0) {
      pills.add(pill(
        Icons.warning_amber_rounded,
        '${data.alertNotSaved} ${data.alertNotSaved == 1 ? 'enquiry' : 'enquiries'} not saved as leads',
        crm.destructive,
        onTap: onShowSources,
        action: 'See channels',
      ));
    }
    if (data.alertOverdue > 0) {
      pills.add(pill(
        Icons.schedule,
        '${data.alertOverdue} follow-up${data.alertOverdue == 1 ? '' : 's'} overdue',
        crm.warning,
        onTap: () => context.go('/sales/leads'),
        action: 'Open leads',
      ));
    }
    if (isToday && !data.todayCountEntered) {
      pills.add(pill(
        Icons.edit_note,
        "Today's team lead count isn't entered yet",
        crm.warning,
        onTap: canEnterCount ? () => context.go('/sales/home') : null,
        action: canEnterCount ? 'Enter count' : null,
      ));
    } else if (isToday && data.todayCountEntered) {
      pills.add(pill(Icons.check_circle_outline, "Today's team count is in", const Color(0xFF16A34A)));
    }
    if (pills.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: pills),
    );
  }
}

// ── Target bar ──────────────────────────────────────────────────────────────

class TargetCard extends StatelessWidget {
  const TargetCard({super.key, required this.target, required this.canSetTargets});
  final OverviewTarget target;
  final bool canSetTargets;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final t = target;
    final month = DateFormat('MMMM yyyy').format(DateTime(t.year, t.month));
    final who = t.scope == 'person' ? 'Salesperson target' : 'Team target';

    if (!t.hasTarget) {
      return DashCard(
        title: '$who · $month',
        child: Row(
          children: [
            Expanded(
              child: Text('No target set for this month.',
                  style: TextStyle(fontSize: 13, color: crm.textSecondary)),
            ),
            if (canSetTargets)
              TextButton(onPressed: () => context.go('/sales/targets'), child: const Text('Set targets')),
          ],
        ),
      );
    }

    return DashCard(
      title: '$who · $month',
      subtitle: '${t.workingDaysElapsed} of ${t.workingDays} working days · same figures as Sales Targets',
      child: LayoutBuilder(builder: (context, c) {
        final bars = [
          if (t.bookingsTarget > 0)
            _TargetBar(
              label: 'Bookings',
              achieved: t.bookings.toDouble(),
              target: t.bookingsTarget.toDouble(),
              expected: t.expectedBookings,
              format: (v) => v.round().toString(),
            ),
          if (t.valueTarget > 0)
            _TargetBar(
              label: 'Order value',
              achieved: t.value,
              target: t.valueTarget,
              expected: t.expectedValue,
              format: money,
            ),
        ];
        if (c.maxWidth < 560) {
          return Column(children: [
            for (final b in bars) Padding(padding: const EdgeInsets.only(bottom: 12), child: b),
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < bars.length; i++) ...[
              Expanded(child: bars[i]),
              if (i < bars.length - 1) const SizedBox(width: 24),
            ],
          ],
        );
      }),
    );
  }
}

class _TargetBar extends StatelessWidget {
  const _TargetBar({
    required this.label,
    required this.achieved,
    required this.target,
    required this.expected,
    required this.format,
  });
  final String label;
  final double achieved, target, expected;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final frac = target > 0 ? (achieved / target).clamp(0.0, 1.0) : 0.0;
    final mark = target > 0 ? (expected / target).clamp(0.0, 1.0) : 0.0;
    final onPace = achieved >= expected;
    final color = onPace ? const Color(0xFF16A34A) : crm.warning;
    final gap = expected - achieved;
    final status = onPace
        ? 'On pace'
        : 'Behind by ${format(gap)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: crm.textSecondary)),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: format(achieved),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: crm.textPrimary)),
                  TextSpan(text: ' / ${format(target)}', style: TextStyle(fontSize: 13, color: crm.textSecondary)),
                ])),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          return SizedBox(
            height: 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: 3,
                  bottom: 3,
                  child: Container(
                    decoration: BoxDecoration(color: crm.border, borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 3,
                  bottom: 3,
                  width: c.maxWidth * frac,
                  child: Container(
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                if (mark > 0)
                  Positioned(
                    left: (c.maxWidth * mark - 1).clamp(0.0, c.maxWidth - 2),
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: Container(color: crm.textPrimary),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 2,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(onPace ? Icons.check_circle : Icons.trending_down, size: 14, color: color),
              const SizedBox(width: 4),
              Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ]),
            Text('${(frac * 100).toStringAsFixed(0)}% done · line = where you should be today',
                style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ],
        ),
      ],
    );
  }
}

// ── Key numbers ─────────────────────────────────────────────────────────────

class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.data, required this.isMobile});
  final SalesOverview data;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final k = data.kpis;

    String delta(num now, num before, {bool isMoney = false}) {
      final d = now - before;
      if (d == 0) return 'same as previous period';
      final s = isMoney ? money(d.abs().toDouble()) : '${d.abs()}';
      return '${d > 0 ? '+' : '−'}$s vs previous period';
    }

    final tiles = <_KpiTile>[
      _KpiTile(
        key: const ValueKey('kpi-enquiries'),
        label: 'Enquiries',
        value: k.enquiries == null ? '—' : '${k.enquiries}',
        note: k.enquiries == null
            ? 'not entered for this period'
            : '${k.savedOnCountDays} saved · ${k.notSaved > 0 ? '${k.notSaved} not saved' : 'all saved'}'
                '${k.enquiryDays < k.days ? ' · ${k.enquiryDays}/${k.days} days counted' : ''}',
        noteColor: k.enquiries != null && k.notSaved > 0 ? crm.destructive : crm.textSecondary,
        icon: Icons.forum_outlined,
        color: _cCount,
      ),
      _KpiTile(
        key: const ValueKey('kpi-bookings'),
        label: 'Bookings',
        value: '${k.bookings}',
        note: delta(k.bookings, data.prevBookings),
        icon: Icons.event_available_outlined,
        color: _cSaved,
      ),
      _KpiTile(
        key: const ValueKey('kpi-value'),
        label: 'Order value',
        value: money(k.orderValue),
        note: 'avg ${money(k.avgOrderValue)} · advance ${money(k.advance)}',
        icon: Icons.payments_outlined,
        color: _cValue,
      ),
      _KpiTile(
        key: const ValueKey('kpi-conversion'),
        label: 'Conversion',
        value: '${k.conversion.toStringAsFixed(1)}%',
        note: k.conversionBasis == 'enquiries' ? 'bookings ÷ team count' : 'bookings ÷ ${k.leads} leads',
        icon: Icons.trending_up,
        color: const Color(0xFFF59E0B),
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 640 ? 2 : 4;
      const gap = 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
    this.noteColor,
  });
  final String label, value, note;
  final IconData icon;
  final Color color;
  final Color? noteColor;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: crm.textPrimary)),
          ),
          const SizedBox(height: 4),
          Text(note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: noteColor ?? crm.textSecondary)),
        ],
      ),
    );
  }
}

/// Two cards side by side when there is room, stacked otherwise.
class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});
  final Widget left, right;


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 900) {
        return Column(children: [left, const SizedBox(height: 12), right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: left),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: right),
        ],
      );
    });
  }
}

// ── Overview tab ────────────────────────────────────────────────────────────

class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key, required this.data, required this.isMobile});
  final SalesOverview data;
  final bool isMobile;

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  bool _showValue = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      children: [
        _Pair(
          left: DashCard(
            title: _showValue ? 'Order value by day' : 'Team count vs leads saved',
            subtitle: _showValue ? 'Bookings made each day' : 'Days with no team count show leads only',
            trailing: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: false, label: Text('Leads')),
                ButtonSegment(value: true, label: Text('Value')),
              ],
              selected: {_showValue},
              onSelectionChanged: (s) => setState(() => _showValue = s.first),
            ),
            child: SizedBox(height: 220, child: _TrendChart(days: d.trend, showValue: _showValue)),
          ),
          // The team count joins the funnel only when every day of the period
          // has one — a partial count above a full period of leads misleads.
          right: _FunnelCard(
              funnel: d.funnel,
              enquiries: d.kpis.enquiryDays == d.kpis.days ? d.kpis.enquiries : null,
              bookings: d.kpis.bookings),
        ),
        const SizedBox(height: 12),
        _CollectionsCard(k: d.kpis),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.days, required this.showValue});
  final List<OverviewDay> days;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (days.isEmpty) {
      return Center(child: Text('No data for this period', style: TextStyle(color: crm.textSecondary)));
    }
    double maxY = 1;
    for (final r in days) {
      maxY = math.max(maxY, showValue ? r.orderValue : math.max((r.enquiries ?? 0).toDouble(), math.max(r.saved, r.leads).toDouble()));
    }
    final step = math.max(1, (days.length / 8).ceil());
    final groups = <BarChartGroupData>[
      for (var i = 0; i < days.length; i++)
        BarChartGroupData(
          x: i,
          barsSpace: 2,
          barRods: showValue
              ? [BarChartRodData(toY: days[i].orderValue, color: _cValue, width: days.length > 20 ? 6 : 12, borderRadius: BorderRadius.circular(3))]
              : [
                  BarChartRodData(
                      toY: (days[i].enquiries ?? 0).toDouble(),
                      color: _cCount,
                      width: days.length > 20 ? 4 : 9,
                      borderRadius: BorderRadius.circular(2)),
                  BarChartRodData(
                      toY: (days[i].enquiries == null ? days[i].leads : days[i].saved).toDouble(),
                      color: _cSaved,
                      width: days.length > 20 ? 4 : 9,
                      borderRadius: BorderRadius.circular(2)),
                ],
        ),
    ];
    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.15,
              barGroups: groups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: crm.border, strokeWidth: 0.6),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: showValue ? 46 : 28,
                    // Skip the top (max) label — it collides with the one below.
                    getTitlesWidget: (v, meta) => v >= meta.max
                        ? const SizedBox.shrink()
                        : Text(
                            showValue ? money(v) : v.toInt().toString(),
                            style: TextStyle(fontSize: 10, color: crm.textSecondary),
                          ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= days.length || i % step != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(DateFormat('d MMM').format(days[i].date),
                            style: TextStyle(fontSize: 10, color: crm.textSecondary)),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, rodIndex) {
                    final r = days[group.x];
                    final day = DateFormat('d MMM').format(r.date);
                    if (showValue) {
                      return BarTooltipItem('$day\n${fullMoney(r.orderValue)} · ${r.bookings} booking${r.bookings == 1 ? '' : 's'}',
                          const TextStyle(color: Colors.white, fontSize: 11));
                    }
                    return BarTooltipItem(
                        rodIndex == 0
                            ? '$day\nTeam count ${r.enquiries ?? '—'}'
                            : '$day\n${r.enquiries == null ? 'Leads ${r.leads}' : 'Saved ${r.saved}'}',
                        const TextStyle(color: Colors.white, fontSize: 11));
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          children: showValue
              ? [_legend(crm, _cValue, 'Order value')]
              : [_legend(crm, _cCount, 'Team count'), _legend(crm, _cSaved, 'Leads saved')],
        ),
      ],
    );
  }

  Widget _legend(CrmTheme crm, Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
      ]);
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.funnel, required this.enquiries, required this.bookings});
  final OverviewFunnel funnel;
  final int? enquiries;
  final int bookings;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final steps = <(String, int, Color)>[
      if (enquiries != null) ('Enquiries (team count)', enquiries!, _cCount),
      ('Leads', funnel.leads, const Color(0xFF8B5CF6)),
      ('Contacted', funnel.contacted, const Color(0xFF3B82F6)),
      ('Follow-up or later', funnel.followUp, const Color(0xFF0EA5E9)),
      ('Converted', funnel.converted, _cSaved),
      ('Bookings', bookings, const Color(0xFF16A34A)),
    ];
    final top = steps.map((s) => s.$2).fold(0, math.max);
    return DashCard(
      title: 'Funnel',
      subtitle: 'Each stage includes the leads that went further',
      child: Column(
        children: [
          for (final s in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LayoutBuilder(builder: (context, c) {
                final frac = top == 0 ? 0.0 : s.$2 / top;
                return Stack(
                  children: [
                    Container(
                      height: 30,
                      width: math.max(c.maxWidth * frac, 4),
                      decoration: BoxDecoration(
                        color: s.$3.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    SizedBox(
                      height: 30,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(children: [
                          Expanded(
                            child: Text(s.$1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: crm.textPrimary)),
                          ),
                          Text('${s.$2}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                        ]),
                      ),
                    ),
                  ],
                );
              }),
            ),
          if (funnel.lost > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${funnel.lost} lost or awaiting lost approval',
                  style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ),
        ],
      ),
    );
  }
}

class _CollectionsCard extends StatelessWidget {
  const _CollectionsCard({required this.k});
  final OverviewKpis k;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final net = k.received + k.outstanding;
    final progress = net <= 0 ? 0.0 : (k.received / net).clamp(0.0, 1.0);
    Widget cell(String label, String value, {Color? color}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color ?? crm.textPrimary)),
              ),
            ],
          ),
        );
    return DashCard(
      title: 'Money',
      subtitle: 'Bookings made in this period',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, c) {
            final a = [
              cell('Order value', money(k.orderValue)),
              cell('Advance', money(k.advance), color: const Color(0xFF16A34A)),
            ];
            final b = [
              cell('Collected after event', money(k.collected), color: const Color(0xFF16A34A)),
              cell('Still to collect', money(k.outstanding), color: k.outstanding > 0 ? crm.warning : null),
            ];
            // Two rows of two on a phone; one row of four otherwise.
            if (c.maxWidth < 520) {
              return Column(children: [Row(children: a), const SizedBox(height: 12), Row(children: b)]);
            }
            return Row(children: [...a, ...b]);
          }),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: crm.border,
              color: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 6),
          Text('${(progress * 100).toStringAsFixed(0)}% received · "still to collect" is after any discount',
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ],
      ),
    );
  }
}

// ── Simple table ────────────────────────────────────────────────────────────

class _Col {
  const _Col(this.label, {this.flex = 1, this.numeric = true});
  final String label;
  final int flex;
  final bool numeric;
}

/// Lightweight responsive table: fixed minimum width, scrolls sideways on a
/// phone instead of squashing.
class _Table extends StatelessWidget {
  const _Table({required this.cols, required this.rows, this.total, this.minWidth = 760});
  final List<_Col> cols;
  final List<List<Widget>> rows;
  final List<Widget>? total;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Widget row(List<Widget> cells, {Color? bg, bool header = false}) => Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: header || bg != null ? null : BoxDecoration(border: Border(top: BorderSide(color: crm.border))),
          child: Row(children: [
            for (var i = 0; i < cols.length; i++)
              Expanded(
                flex: cols[i].flex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Align(alignment: cols[i].numeric ? Alignment.centerRight : Alignment.centerLeft, child: cells[i]),
                ),
              ),
          ]),
        );
    TextStyle head = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.textSecondary);
    return LayoutBuilder(builder: (context, c) {
      final w = math.max(c.maxWidth, minWidth);
      final table = SizedBox(
        width: w,
        child: Column(children: [
          row([for (final col in cols) Text(col.label, style: head, textAlign: col.numeric ? TextAlign.right : TextAlign.left)],
              bg: crm.background, header: true),
          for (final r in rows) row(r),
          if (total != null) row(total!, bg: crm.primary.withValues(alpha: 0.06)),
        ]),
      );
      return c.maxWidth >= minWidth ? table : SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
    });
  }
}

Widget _t(BuildContext context, String s, {bool bold = false, Color? color}) => Text(
      s,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        color: color ?? context.crmColors.textPrimary,
      ),
    );

Widget _gap(BuildContext context, int n, {bool bold = false}) {
  final crm = context.crmColors;
  if (n == 0) return _t(context, '✓ 0', bold: bold, color: const Color(0xFF16A34A));
  return _t(context, n > 0 ? '$n' : '+${-n} extra', bold: true, color: n > 0 ? crm.destructive : crm.warning);
}

// ── Leads and sources tab ───────────────────────────────────────────────────

class SourcesTab extends StatelessWidget {
  const SourcesTab({super.key, required this.data});
  final SalesOverview data;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final rows = data.sources.where((s) => !s.isEmpty).toList();
    final k = data.kpis;
    final hasCount = k.enquiries != null;
    int sum(int Function(OverviewSource) f) => rows.fold(0, (a, s) => a + f(s));
    final leads = sum((s) => s.leads);
    final conv = sum((s) => s.converted);

    return Column(
      children: [
        DashCard(
          title: 'By channel',
          subtitle: hasCount
              ? 'Team count vs leads saved on the same days, then what those leads became'
              : 'No team count entered for this period — showing saved leads only',
          child: rows.isEmpty && data.directBookings == 0
              ? Text('No enquiries, leads or bookings in this period.',
                  style: TextStyle(fontSize: 13, color: crm.textSecondary))
              : _Table(
                  minWidth: 820,
                  cols: const [
                    _Col('Channel', flex: 3, numeric: false),
                    _Col('Team count'),
                    _Col('Saved'),
                    _Col('Not saved'),
                    _Col('Leads'),
                    _Col('Converted'),
                    _Col('Conv. %'),
                    _Col('Bookings'),
                    _Col('Order value', flex: 2),
                  ],
                  rows: [
                    for (final s in rows)
                      [
                        _t(context, s.channel, bold: true),
                        _t(context, hasCount ? '${s.enquiries}' : '—'),
                        _t(context, hasCount ? '${s.saved}' : '—'),
                        hasCount ? _gap(context, s.notSaved) : _t(context, '—'),
                        _t(context, '${s.leads}'),
                        _t(context, '${s.converted}'),
                        _t(context, s.leads == 0 ? '—' : '${s.conversion.toStringAsFixed(0)}%'),
                        _t(context, '${s.bookings}'),
                        _t(context, money(s.orderValue)),
                      ],
                    if (data.directBookings > 0)
                      [
                        _t(context, 'Direct / no lead', color: crm.textSecondary),
                        _t(context, '—'),
                        _t(context, '—'),
                        _t(context, '—'),
                        _t(context, '—'),
                        _t(context, '—'),
                        _t(context, '—'),
                        _t(context, '${data.directBookings}'),
                        _t(context, money(data.directOrderValue)),
                      ],
                  ],
                  total: [
                    _t(context, 'Total', bold: true),
                    _t(context, hasCount ? '${k.enquiries}' : '—', bold: true),
                    _t(context, hasCount ? '${k.savedOnCountDays}' : '—', bold: true),
                    hasCount ? _gap(context, k.notSaved, bold: true) : _t(context, '—'),
                    _t(context, '$leads', bold: true),
                    _t(context, '$conv', bold: true),
                    _t(context, leads == 0 ? '—' : '${(conv * 100 / leads).toStringAsFixed(0)}%', bold: true),
                    _t(context, '${k.bookings}', bold: true),
                    _t(context, money(k.orderValue), bold: true),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        DashCard(
          title: 'Recent leads',
          trailing: TextButton(onPressed: () => context.go('/sales/leads'), child: const Text('All leads')),
          child: data.recentLeads.isEmpty
              ? Text('No leads in this period.', style: TextStyle(fontSize: 13, color: crm.textSecondary))
              : _Table(
                  minWidth: 640,
                  cols: const [
                    _Col('Name', flex: 3, numeric: false),
                    _Col('Channel', flex: 3, numeric: false),
                    _Col('Status', flex: 2, numeric: false),
                    _Col('Assigned to', flex: 2, numeric: false),
                    _Col('Date', flex: 2),
                  ],
                  rows: [
                    for (final l in data.recentLeads)
                      [
                        _t(context, l.name, bold: true),
                        _t(context, l.source),
                        _StatusPill(l.status),
                        _t(context, l.assignedTo.isEmpty ? '—' : l.assignedTo),
                        _t(context, DateTime.tryParse(l.date) == null ? l.date : DateFormat('d MMM').format(DateTime.parse(l.date))),
                      ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final color = switch (s) {
      'converted' => const Color(0xFF16A34A),
      'lost' || 'pending lost approval' => const Color(0xFFDC2626),
      'follow-up' => const Color(0xFFF59E0B),
      'qualified' => const Color(0xFF0EA5E9),
      'contacted' => const Color(0xFF3B82F6),
      _ => const Color(0xFF6366F1),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ── Team tab ────────────────────────────────────────────────────────────────

class TeamTab extends StatelessWidget {
  const TeamTab({super.key, required this.data});
  final SalesOverview data;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (data.team.isEmpty) {
      return DashCard(
        child: Text('No salespeople found.', style: TextStyle(fontSize: 13, color: crm.textSecondary)),
      );
    }
    final month = DateFormat('MMM').format(DateTime(data.target.year, data.target.month));
    return DashCard(
      title: 'Team leaderboard',
      subtitle: 'Bookings credited to the salesperson (else the lead owner) · month target for $month',
      child: _Table(
        minWidth: 900,
        cols: [
          const _Col('#', numeric: false),
          const _Col('Salesperson', flex: 3, numeric: false),
          const _Col('Leads'),
          const _Col('Calls'),
          const _Col('Follow-ups'),
          const _Col('Overdue'),
          const _Col('Bookings'),
          const _Col('Order value', flex: 2),
          _Col('$month target', flex: 3, numeric: false),
        ],
        rows: [
          for (final (i, p) in data.team.indexed)
            [
              _t(context, '${i + 1}', color: crm.textSecondary),
              _t(context, p.name, bold: true),
              _t(context, '${p.leads}'),
              _t(context, '${p.calls}'),
              _t(context, '${p.followUps}'),
              p.overdueFollowUps > 0
                  ? _t(context, '${p.overdueFollowUps}', bold: true, color: crm.warning)
                  : _t(context, '0'),
              _t(context, '${p.bookings}'),
              _t(context, money(p.orderValue), bold: true),
              Padding(padding: const EdgeInsets.only(left: 12), child: _MiniTarget(person: p)),
            ],
          if (data.othersBookings > 0)
            [
              _t(context, ''),
              _t(context, 'Not credited to a salesperson', color: crm.textSecondary),
              _t(context, ''),
              _t(context, ''),
              _t(context, ''),
              _t(context, ''),
              _t(context, '${data.othersBookings}'),
              _t(context, money(data.othersOrderValue)),
              _t(context, ''),
            ],
        ],
      ),
    );
  }
}

class _MiniTarget extends StatelessWidget {
  const _MiniTarget({required this.person});
  final OverviewPerson person;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final t = person.monthValueTarget;
    if (t <= 0) return Text('No target', style: TextStyle(fontSize: 12, color: crm.textSecondary));
    final frac = (person.monthValue / t).clamp(0.0, 1.0);
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: frac, minHeight: 7, backgroundColor: crm.border, color: _cSaved),
        ),
      ),
      const SizedBox(width: 8),
      Text('${(person.monthValue * 100 / t).toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.textPrimary)),
    ]);
  }
}

// ── Reports tab ─────────────────────────────────────────────────────────────

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key, required this.data, required this.onExport});
  final SalesOverview data;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final rows = data.trend.reversed.toList();
    final k = data.kpis;
    final leads = data.trend.fold(0, (a, r) => a + r.leads);
    return DashCard(
      title: 'Day-by-day report',
      subtitle: 'Newest first',
      trailing: OutlinedButton.icon(
        onPressed: onExport,
        icon: const Icon(Icons.download, size: 16),
        label: const Text('CSV'),
      ),
      child: _Table(
        minWidth: 640,
        cols: const [
          _Col('Date', flex: 2, numeric: false),
          _Col('Team count'),
          _Col('Saved'),
          _Col('Not saved'),
          _Col('Leads'),
          _Col('Bookings'),
          _Col('Order value', flex: 2),
        ],
        rows: [
          for (final r in rows)
            [
              _t(context, DateFormat('EEE d MMM').format(r.date), bold: true),
              _t(context, r.enquiries == null ? '—' : '${r.enquiries}'),
              _t(context, r.enquiries == null ? '—' : '${r.saved}'),
              r.enquiries == null ? _t(context, '—') : _gap(context, r.enquiries! - r.saved),
              _t(context, '${r.leads}'),
              _t(context, '${r.bookings}'),
              _t(context, money(r.orderValue)),
            ],
        ],
        total: [
          _t(context, 'Total', bold: true),
          _t(context, k.enquiries == null ? '—' : '${k.enquiries}', bold: true),
          _t(context, k.enquiries == null ? '—' : '${k.savedOnCountDays}', bold: true),
          k.enquiries == null ? _t(context, '—') : _gap(context, k.notSaved, bold: true),
          _t(context, '$leads', bold: true),
          _t(context, '${k.bookings}', bold: true),
          _t(context, money(k.orderValue), bold: true),
        ],
      ),
    );
  }
}
