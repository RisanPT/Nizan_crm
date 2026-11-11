import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/fleet/data/expense_split.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/map_link.dart';
import 'package:url_launcher/url_launcher.dart';

final _money = NumberFormat.decimalPattern('en_IN');

/// ₹1,000 — and ₹33.34 when there are paise.
String rupees(double v) {
  final whole = (v - v.roundToDouble()).abs() < 0.005;
  return '₹${whole ? _money.format(v.round()) : NumberFormat('#,##0.00', 'en_IN').format(v)}';
}

/// Beyond this many works the list is collapsed (with a "Show all" button).
const _collapsedAfter = 4;
const _collapsedShows = 3;

/// In Accounts: which work(s) an expense belongs to, who the artist is on each,
/// and how much each work carries. A whole-day expense is shared EQUALLY across
/// that day's works.
class ExpenseWorkSplit extends StatefulWidget {
  final ExpenseSplit split;
  const ExpenseWorkSplit({super.key, required this.split});

  @override
  State<ExpenseWorkSplit> createState() => _ExpenseWorkSplitState();
}

class _ExpenseWorkSplitState extends State<ExpenseWorkSplit> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final s = widget.split;
    final works = s.works;
    final collapsed = !_showAll && works.length > _collapsedAfter;
    final shown = collapsed ? works.take(_collapsedShows).toList() : works;
    final each = s.eachAmount;

    final (title, icon, color) = switch (s.mode) {
      'shared' => ('Whole day — shared equally across ${works.length} works', Icons.call_split_rounded, c.primary),
      'direct' => ('Charged to this work', Icons.work_outline, c.textPrimary),
      _ => ('Not under any work', Icons.help_outline, c.warning),
    };

    TextStyle small([Color? col, FontWeight? w, double size = 12.5]) =>
        TextStyle(fontSize: size, color: col ?? c.textSecondary, fontWeight: w, height: 1.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: small(color, FontWeight.w700, 13))),
              if (s.isShared && each != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${rupees(each)} each', style: small(c.primary, FontWeight.w800, 12)),
                ),
            ],
          ),
        ),
        if (!s.counted)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('Rejected — not counted as a cost.', style: small(c.destructive, FontWeight.w600)),
          ),
        if (s.mode == 'unallocated' && s.reason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(s.reason, style: small(c.warning, FontWeight.w600)),
          ),
        for (final w in shown) _WorkRow(work: w, showAmount: s.mode != 'direct' || works.length > 1),
        if (collapsed)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showAll = true),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
              child: Text('Show all ${works.length} works'),
            ),
          ),
      ],
    );
  }
}

class _WorkRow extends StatelessWidget {
  final SplitWork work;
  final bool showAmount;
  const _WorkRow({required this.work, required this.showAmount});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final time = work.start == null ? '' : DateFormat('h:mm a').format(work.start!);
    // The client leads: that is how Accounts recognises the work. Booking number
    // and time are the detail underneath.
    final client = work.customerName.trim();
    final title = client.isNotEmpty ? client : (work.bookingNumber.isNotEmpty ? work.bookingNumber : 'Work');
    final detail = [if (client.isNotEmpty && work.bookingNumber.isNotEmpty) work.bookingNumber, if (time.isNotEmpty) time]
        .join(' · ');
    final noArtist = work.artists.isEmpty;
    final map = mapLaunchUri(work.mapUrl);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.textPrimary)),
                if (detail.isNotEmpty)
                  Text(detail, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.brush_outlined, size: 13, color: noArtist ? c.warning : c.textSecondary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        artistSummary(work.artists),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: noArtist ? c.warning : c.textPrimary,
                          fontWeight: noArtist ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (work.place.isNotEmpty || map != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.place_outlined, size: 13, color: c.textSecondary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            work.place.isEmpty ? 'Location on the map' : work.place,
                            style: TextStyle(fontSize: 11.5, height: 1.3, color: c.textSecondary),
                          ),
                        ),
                        if (map != null)
                          InkWell(
                            onTap: () => launchUrl(map, mode: LaunchMode.externalApplication),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text('Map', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.primary)),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (showAmount) ...[
            const SizedBox(width: 10),
            Text(rupees(work.amount), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.textPrimary)),
          ],
        ],
      ),
    );
  }
}
