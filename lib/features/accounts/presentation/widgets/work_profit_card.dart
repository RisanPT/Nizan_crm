import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/accounts/data/work_profit.dart';

/// ₹1,23,456 or ₹1,234.56 — rupees, with paise only when there are some.
String profitRupees(double v) {
  final whole = v == v.roundToDouble();
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: whole ? 0 : 2,
  ).format(v);
}

/// "71%" / "-20%" / "—" — a margin.
String marginText(double? pct) {
  if (pct == null) return '—';
  return '${pct == pct.roundToDouble() ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1)}%';
}

const _categoryLabels = <String, String>{
  'food': 'Food',
  'travel': 'Travel',
  'stay': 'Stay',
  'materials': 'Materials',
  'fuel': 'Fuel',
  'toll': 'Toll',
  'parking': 'Parking',
  'service': 'Service / repair',
  'other': 'Other',
  'payout': 'Payout',
};

/// Red for a loss, amber for a thin margin, green otherwise.
Color profitColor(CrmTheme crm, WorkProfit w) =>
    w.isLoss ? crm.destructive : (w.isThin ? crm.warning : crm.success);

/// ONE WORK'S PROFIT: what it earned (GST taken out), what it cost (artists, fleet, freelancers), and
/// what is left — with the part of the cost that is not verified yet called out, never hidden.
class WorkProfitCard extends StatefulWidget {
  final WorkProfit work;
  final double thinMarginPct;
  const WorkProfitCard({
    super.key,
    required this.work,
    this.thinMarginPct = 20,
  });

  @override
  State<WorkProfitCard> createState() => _WorkProfitCardState();
}

class _WorkProfitCardState extends State<WorkProfitCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final w = widget.work;
    final color = profitColor(crm, w);
    final when = w.serviceStart == null
        ? ''
        : DateFormat('EEE d MMM').format(w.serviceStart!);

    return Container(
      key: Key('workProfitCard_${w.bookingId}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: w.isLoss ? crm.destructive.withValues(alpha: 0.5) : crm.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    w.customerName.isEmpty ? 'Work' : w.customerName,
                    if (w.bookingNumber.isNotEmpty) w.bookingNumber,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary,
                  ),
                ),
              ),
              Container(
                key: Key('marginChip_${w.bookingId}'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  marginText(w.marginPct),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              when,
              w.service,
              w.place,
              if (w.artists.isNotEmpty) w.artists.join(', '),
            ].where((x) => x.isNotEmpty).join('  ·  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: crm.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(
            'PROFIT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: crm.textSecondary,
            ),
          ),
          Text(
            profitRupees(w.profit),
            key: Key('profitValue_${w.bookingId}'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          _SplitBar(work: w, crm: crm),
          const SizedBox(height: 10),
          _line(
            crm,
            'Revenue (without GST)',
            profitRupees(w.revenue.taxable),
            bold: true,
            key: 'revenue',
          ),
          if (w.revenue.gst > 0 || w.revenue.discount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 2),
              child: Text(
                [
                  'Booked ${profitRupees(w.revenue.gross)}',
                  if (w.revenue.discount > 0)
                    'discount ${profitRupees(w.revenue.discount)}',
                  if (w.revenue.gst > 0) 'GST ${profitRupees(w.revenue.gst)}',
                ].join('  ·  '),
                style: TextStyle(fontSize: 11, color: crm.textSecondary),
              ),
            ),
          _line(
            crm,
            'Artists',
            '−${profitRupees(w.costs.artist.total)}',
            dot: _Dots.artist(crm),
            key: 'artist',
          ),
          _line(
            crm,
            'Fleet',
            '−${profitRupees(w.costs.fleet.total)}',
            dot: _Dots.fleet(crm),
            key: 'fleet',
          ),
          _line(
            crm,
            'Freelancers',
            '−${profitRupees(w.costs.freelance.total)}',
            dot: _Dots.freelance(crm),
            key: 'freelance',
          ),
          const Divider(height: 14),
          _line(
            crm,
            'Costs',
            profitRupees(w.costs.total),
            bold: true,
            key: 'costs',
          ),
          if (w.flags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final f in w.flags) _flag(crm, f, w)],
            ),
          ],
          InkWell(
            key: Key('profitDetails_${w.bookingId}'),
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: crm.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _open ? 'Hide details' : 'Details',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: crm.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_open) _details(crm, w),
        ],
      ),
    );
  }

  Widget _line(
    CrmTheme crm,
    String label,
    String value, {
    bool bold = false,
    Widget? dot,
    required String key,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        if (dot != null) ...[dot, const SizedBox(width: 6)],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: crm.textPrimary,
            ),
          ),
        ),
        Text(
          value,
          key: Key('${key}_${widget.work.bookingId}'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: crm.textPrimary,
          ),
        ),
      ],
    ),
  );

  Widget _flag(CrmTheme crm, String f, WorkProfit w) {
    final (text, color, icon) = switch (f) {
      'loss' => (
        'Loss — it cost more than it earned',
        crm.destructive,
        Icons.trending_down,
      ),
      'thin' => (
        'Thin margin — under ${widget.thinMarginPct.toStringAsFixed(0)}%',
        crm.warning,
        Icons.warning_amber_rounded,
      ),
      'pending_costs' => (
        '${profitRupees(w.costs.pending)} of the costs not verified yet',
        crm.warning,
        Icons.hourglass_top_rounded,
      ),
      'no_costs' => (
        'No costs recorded — profit may be overstated',
        crm.textSecondary,
        Icons.info_outline_rounded,
      ),
      _ => (f, crm.textSecondary, Icons.info_outline_rounded),
    };
    return Container(
      key: Key('flag_${f}_${w.bookingId}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(CrmTheme crm, String title, CostGroup g, {String? note}) {
    if (g.total == 0) return const SizedBox.shrink();
    final cats = g.byCategory.entries.where((e) => e.value != 0).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: crm.textSecondary,
            ),
          ),
          for (final e in cats)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _categoryLabels[e.key] ?? e.key,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  Text(
                    profitRupees(e.value),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (g.pending > 0)
            Text(
              '${profitRupees(g.pending)} not verified yet',
              style: TextStyle(
                fontSize: 11.5,
                color: crm.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (note != null)
            Text(
              note,
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _details(CrmTheme crm, WorkProfit w) => Column(
    key: Key('profitDetailsBody_${w.bookingId}'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _group(crm, 'ARTISTS', w.costs.artist),
      _group(
        crm,
        'FLEET',
        w.costs.fleet,
        note: w.costs.fleet.shared > 0
            ? '${profitRupees(w.costs.fleet.shared)} is a share of a whole-day cost, split equally over the driver\'s works that day'
            : null,
      ),
      _group(crm, 'FREELANCERS', w.costs.freelance),
      Text(
        'PAYMENT',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: crm.textSecondary,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          'Customer pays ${profitRupees(w.revenue.net)} · received ${profitRupees(w.revenue.received)} · outstanding ${profitRupees(w.revenue.outstanding)}',
          style: const TextStyle(fontSize: 12.5),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Salaries, rent and other overheads are not included.',
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: crm.textSecondary,
        ),
      ),
    ],
  );
}

class _Dots {
  static Widget _dot(Color c) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
  static Widget artist(CrmTheme crm) => _dot(artistColor(crm));
  static Widget fleet(CrmTheme crm) => _dot(fleetColor(crm));
  static Widget freelance(CrmTheme crm) => _dot(freelanceColor(crm));
}

Color artistColor(CrmTheme crm) => crm.primary;
Color fleetColor(CrmTheme crm) => crm.accent;
Color freelanceColor(CrmTheme crm) => crm.warning;

/// Where the revenue went: artists, fleet, freelancers — and what is left. A loss fills the bar with costs only.
class _SplitBar extends StatelessWidget {
  final WorkProfit work;
  final CrmTheme crm;
  const _SplitBar({required this.work, required this.crm});

  @override
  Widget build(BuildContext context) {
    final c = work.costs;
    final left = work.profit > 0 ? work.profit : 0.0;
    final total = c.artist.total + c.fleet.total + c.freelance.total + left;
    if (total <= 0) return const SizedBox.shrink();
    Widget seg(double v, Color color) => v <= 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: (v / total * 1000).round().clamp(1, 1000),
            child: ColoredBox(color: color),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        key: Key('splitBar_${work.bookingId}'),
        height: 8,
        child: Row(
          children: [
            seg(c.artist.total, artistColor(crm)),
            seg(c.fleet.total, fleetColor(crm)),
            seg(c.freelance.total, freelanceColor(crm)),
            seg(left, crm.success.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }
}
