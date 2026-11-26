import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/marketing/data/lead_report_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart';
import 'package:nizan_crm/features/marketing/services/lead_report_service.dart';

/// Lead Report → Conversion: how leads become bookings. A booking is a lead linked to a live CRM booking (one per lead — a Converted lead
/// whose booking was cancelled is not one); booking value is that booking after discount with GST backed out (the same revenue Work Profit
/// and the Campaigns hub use). Cost per booking = the ad spend of these dates ÷ the campaign leads' bookings, only where spend is recorded.
class LeadConversionTab extends ConsumerWidget {
  const LeadConversionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => LrAsync<ConversionData>(
        value: ref.watch(leadConversionProvider),
        listKey: const Key('lr_conversion_list'),
        builder: (context, c) {
          final k = c.kpis;
          return [
            MktKpiRow(minWidth: 180, children: [
              leadKpi(key: 'lr_cv_rate', icon: Icons.percent_rounded, label: 'Conversion Rate', value: pctText(k.conversionRate), change: k.change['conversionRate'], points: true, tint: Mkt.primary),
              leadKpi(key: 'lr_cv_bookings', icon: Icons.event_available_outlined, label: 'Total Bookings', value: '${k.bookings}', change: k.change['bookings'], tint: Mkt.blue),
              leadKpi(key: 'lr_cv_value', icon: Icons.currency_rupee_rounded, label: 'Booking Value (ex-GST)', value: k.bookings == 0 ? '—' : rupees(k.bookingValue), change: k.change['bookingValue'], tint: Mkt.warn),
              leadKpi(key: 'lr_cv_cpb', icon: Icons.account_balance_wallet_outlined, label: 'Cost per Booking', value: costText(c.costs.costPerBooking), note: c.costs.adSpend == null ? 'No ad spend recorded for these dates' : '${costText(c.costs.adSpend)} spent ÷ ${c.costs.bookings} campaign booking${c.costs.bookings == 1 ? '' : 's'}', tint: Mkt.pink),
            ]),
            if (k.unvalued > 0) LrNote('${k.unvalued} booking${k.unvalued == 1 ? ' was' : 's were'} entered by a user left out of sales totals, so ${k.unvalued == 1 ? 'it adds' : 'they add'} nothing to the booking value.', key: const Key('lr_cv_unvalued')),
            if (k.converted > k.bookings) LrNote('${k.converted - k.bookings} lead${k.converted - k.bookings == 1 ? ' is' : 's are'} in the Converted stage without a live booking (cancelled or still pending), so ${k.converted - k.bookings == 1 ? 'it is' : 'they are'} not counted as a booking.', key: const Key('lr_cv_not_booked')),
            if (k.bookings > 0) LrNote('Booking value is after discount and excludes GST. Customers pay ${rupees(k.orderValue, compact: false)} including GST.'),
            const SizedBox(height: 12),
            MktGrid(breakpoint: 980, rows: [
              [
                (4, MktCard(title: 'Conversion Funnel', subtitle: 'Each step as a share of all leads', icon: Icons.filter_alt_outlined, child: LeadFunnelView(funnel: c.funnel, keyPrefix: 'lr_cv_funnel'))),
                (5, MktCard(
                  title: 'Conversion Trend',
                  subtitle: 'Leads and their bookings, by the day the lead arrived${c.trend.granularity == 'week' ? ' (by week)' : ''}',
                  icon: Icons.bar_chart_rounded,
                  child: KeyedSubtree(
                    key: const Key('lr_cv_trend'),
                    child: LeadBarChart(rows: c.trend.rows, series: [
                      (key: 'leads', label: 'Leads', color: Mkt.primaryLight, value: (r) => r.leads),
                      (key: 'bookings', label: 'Bookings', color: Mkt.good, value: (r) => r.bookings),
                    ]),
                  ),
                )),
                (3, _BySource(rows: c.bySource)),
              ],
            ]),
          ];
        },
      );
}

class _BySource extends StatelessWidget {
  const _BySource({required this.rows});
  final List<SourceConversion> rows;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Conversion by Source',
        subtitle: 'Bookings ÷ leads, per source',
        icon: Icons.hub_outlined,
        child: rows.isEmpty
            ? const MktEmpty('No leads in this range.', icon: Icons.hub_outlined, height: 120)
            : Column(key: const Key('lr_cv_by_source'), children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w600))),
                        Text('${r.bookings}/${r.leads} · ${pctText(r.rate)}', key: Key('lr_cv_src_${r.key}'), maxLines: 1, style: mktText(11, color: Mkt.inkSoft)),
                      ]),
                      const SizedBox(height: 3),
                      MktProgress(pct: (r.rate ?? 0).round(), color: Mkt.good, showLabel: false, height: 6),
                    ]),
                  ),
              ]),
      );
}
