import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';

/// Calendar month KPIs: bookings, income, received, balance to collect and
/// the month's forecast.
///
/// A booking counts when any of its work dates falls in [month]; cancelled
/// bookings are left out.
///  • Received = money actually recorded: advance + collected payments
///    (or collected payments only when advance is excluded).
///  • Balance to collect = [Booking.balanceDue], the invoices' rule: what is
///    still owed on bookings whose work isn't finished yet.
///  • Forecast = Received + Balance to collect — what the month brings in
///    once every pending balance is collected.
class MonthKpiStrip extends StatefulWidget {
  final DateTime month;
  final List<Booking> bookings;

  /// Phones: one swipeable row of smaller cards so the calendar keeps its height.
  final bool compact;

  const MonthKpiStrip({
    super.key,
    required this.month,
    required this.bookings,
    required this.compact,
  });

  @override
  State<MonthKpiStrip> createState() => _MonthKpiStripState();
}

class _MonthKpiStripState extends State<MonthKpiStrip> {
  /// Count booking advances in income / received / forecast.
  bool _inclAdvance = true;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _inr(double v) {
    final s = v.round().toString();
    if (s.length <= 3) return '₹$s';
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '₹${parts.join(',')},$last3';
  }

  static String _short(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final month = widget.month;
    final compact = widget.compact;
    final label = '${_months[month.month - 1]} ${month.year}';

    final inMonth = <String, Booking>{};
    for (final b in widget.bookings) {
      if (b.status.toLowerCase() == 'cancelled') continue;
      if (b.workDates.any((d) => d.year == month.year && d.month == month.month)) {
        inMonth.putIfAbsent(b.id, () => b);
      }
    }
    final list = inMonth.values.toList();
    final count = list.length;
    final upcoming = list.where((b) => b.hasPendingWork).length;
    final done = count - upcoming;

    double sum(double Function(Booking) f) => list.fold<double>(0, (s, b) => s + f(b));
    final value = sum((b) => (b.totalPrice - b.discountAmount).clamp(0, double.infinity).toDouble());
    final advance = sum((b) => b.advanceAmount);
    final collected = sum((b) => b.collectedAmount);
    final balance = sum((b) => b.balanceDue);
    final pending = list.where((b) => b.balanceDue > 0).length;

    final adv = _inclAdvance ? advance : 0.0;
    final income = (value - (_inclAdvance ? 0 : advance)).clamp(0, double.infinity).toDouble();
    final received = adv + collected;
    final forecast = received + balance;
    final receivedPct = forecast <= 0 ? 0.0 : received / forecast;
    // Completed bookings with no payment recorded beyond what's above.
    final unrecorded = (income - forecast).clamp(0, double.infinity).toDouble();
    final advNote = _inclAdvance ? 'incl. advance' : 'excl. advance';

    String money(double v) => compact ? _short(v) : _inr(v);

    final cards = [
      _Kpi(
        'Total bookings',
        '$count',
        count == 0 ? 'No bookings in $label' : '$done completed · $upcoming upcoming',
        Icons.event_available_rounded,
        crm.primary,
      ),
      _Kpi(
        'Total income',
        money(income),
        count == 0
            ? advNote
            : _inclAdvance
                ? 'Booking value · avg ${_short(income / count)}'
                : 'After ${_short(advance)} advance',
        Icons.payments_rounded,
        const Color(0xFF2563EB),
      ),
      _Kpi(
        'Received',
        money(received),
        _inclAdvance
            ? 'Advance ${_short(advance)} + collected ${_short(collected)}'
            : 'Collected payments only',
        Icons.account_balance_wallet_rounded,
        const Color(0xFF16A34A),
        progress: receivedPct,
      ),
      _Kpi(
        'Balance to collect',
        money(balance),
        pending == 0 ? 'Nothing pending' : 'From $pending upcoming booking${pending == 1 ? '' : 's'}',
        Icons.pending_actions_rounded,
        balance > 0 ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
      ),
      _Kpi(
        'Forecast',
        money(forecast),
        forecast <= 0
            ? advNote
            : '${(receivedPct * 100).toStringAsFixed(0)}% in hand · $advNote',
        Icons.query_stats_rounded,
        const Color(0xFF7C3AED),
        tooltip: 'Received + balance to collect: what $label brings in once every '
            'pending balance is paid ($advNote).'
            '${unrecorded > 0 ? '\n${_inr(unrecorded)} of finished bookings has no payment recorded, '
                'so it is not in the forecast.' : ''}',
      ),
    ];

    final toggle = SegmentedButton<bool>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity(horizontal: -2, vertical: -3),
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      segments: const [
        ButtonSegment(value: true, label: Text('Incl. advance')),
        ButtonSegment(value: false, label: Text('Excl. advance')),
      ],
      selected: {_inclAdvance},
      onSelectionChanged: (s) => setState(() => _inclAdvance = s.first),
    );

    final now = DateTime.now();
    final title = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.insights_rounded, size: 16, color: crm.primary),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          '$label at a glance${month.year == now.year && month.month == now.month ? ' · this month' : ''}',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
        ),
      ),
    ]);
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              title,
              const SizedBox(height: 6),
              toggle,
            ])
          : Row(children: [Expanded(child: title), toggle]),
    );

    if (compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _KpiCard(cards[i], compact: true, width: 214),
          ),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      LayoutBuilder(builder: (context, c) {
        final perRow = c.maxWidth >= 1100 ? 5 : c.maxWidth >= 760 ? 3 : 2;
        final w = (c.maxWidth - 12 * (perRow - 1)) / perRow;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final k in cards) _KpiCard(k, compact: false, width: w)],
        );
      }),
    ]);
  }
}

class _Kpi {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  final double? progress;
  final String? tooltip;
  const _Kpi(this.label, this.value, this.sub, this.icon, this.color, {this.progress, this.tooltip});
}

class _KpiCard extends StatelessWidget {
  final _Kpi k;
  final bool compact;
  final double width;
  const _KpiCard(this.k, {required this.compact, required this.width});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final card = Container(
      width: width,
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: k.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: k.color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 7 : 9),
            decoration: BoxDecoration(
              color: k.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(k.icon, size: compact ? 18 : 22, color: k.color),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(k.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                  if (k.tooltip != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.info_outline_rounded, size: 13, color: crm.textSecondary),
                  ],
                ]),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(k.value,
                      style: TextStyle(
                        fontSize: compact ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary,
                        height: 1.2,
                      )),
                ),
                if (k.progress != null) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: k.progress!.clamp(0, 1).toDouble(),
                      minHeight: 4,
                      backgroundColor: k.color.withValues(alpha: 0.15),
                      color: k.color,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(k.sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
    return k.tooltip == null
        ? card
        : Tooltip(message: k.tooltip!, triggerMode: TooltipTriggerMode.tap, child: card);
  }
}
