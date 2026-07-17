import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/space_extension.dart';
import '../../../../core/models/booking.dart';
import '../../../../core/models/trial.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/providers/trial_provider.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../core/utils/responsive_builder.dart';
import '../../../../presentation/screens/inventory/inventory_widgets.dart';

/// Sales → Quarterly performance inner page. Overall Q1–Q4 view for the
/// selected financial year: works, revenue, advance, and a month breakdown.
class SalesQuarterlyScreen extends ConsumerWidget {
  const SalesQuarterlyScreen({
    super.key,
    required this.financialYear,
    this.dateBasis = 'event_date',
  });

  final String financialYear; // e.g. "2026-27"
  final String dateBasis; // event_date | booking_date

  static String _compact(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
    return '₹${v.toStringAsFixed(0)}';
  }

  // Indian FY quarters and their months.
  static const _quarters = <(String, String, List<int>)>[
    ('Q1', 'Apr – Jun', [4, 5, 6]),
    ('Q2', 'Jul – Sep', [7, 8, 9]),
    ('Q3', 'Oct – Dec', [10, 11, 12]),
    ('Q4', 'Jan – Mar', [1, 2, 3]),
  ];
  static const _monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  bool _active(Booking b) {
    final s = b.status.toLowerCase();
    return s != 'cancelled' && s != 'postponed' && s != 'rejected';
  }

  DateTime _dateOf(Booking b) =>
      dateBasis == 'booking_date' ? (b.createdAt ?? b.bookingDate) : b.bookingDate;

  int _works(Booking b) => b.bookingItems.isEmpty ? 1 : b.bookingItems.length;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(bookingProvider);
    final allTrials = ref.watch(allTrialsProvider).value ?? const <Trial>[];

    final fyStartYear =
        int.tryParse(financialYear.split('-').first) ?? DateTime.now().year;
    final fyStart = DateTime(fyStartYear, 4, 1);
    final fyEnd = DateTime(fyStartYear + 1, 3, 31, 23, 59, 59);

    return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load: $e',
              style: TextStyle(color: crm.textSecondary)),
        ),
        data: (all) {
          final fyBookings = all.where((b) {
            final d = _dateOf(b);
            return !d.isBefore(fyStart) && !d.isAfter(fyEnd);
          }).toList();

          // Per-quarter aggregates.
          final qWorks = List<int>.filled(4, 0);
          final qRevenue = List<double>.filled(4, 0);
          final qAdvance = List<double>.filled(4, 0);
          final qCompleted = List<int>.filled(4, 0);
          final qCancelled = List<int>.filled(4, 0);
          // Per-month works within each quarter (for the breakdown).
          final monthWorks = <int, int>{};
          final monthRevenue = <int, double>{};

          int quarterIndexForMonth(int month) {
            for (var i = 0; i < 4; i++) {
              if (_quarters[i].$3.contains(month)) return i;
            }
            return 0;
          }

          for (final b in fyBookings) {
            final m = _dateOf(b).month;
            final qi = quarterIndexForMonth(m);
            final status = b.status.toLowerCase();
            if (status == 'cancelled') {
              qCancelled[qi] += _works(b);
              continue;
            }
            if (!_active(b)) continue;
            qWorks[qi] += _works(b);
            qRevenue[qi] += b.totalPrice;
            qAdvance[qi] += b.advanceAmount;
            if (status == 'completed') qCompleted[qi] += _works(b);
            monthWorks[m] = (monthWorks[m] ?? 0) + _works(b);
            monthRevenue[m] = (monthRevenue[m] ?? 0) + b.totalPrice;
          }

          // Fold in trials (studio-wide): each non-cancelled trial in the FY
          // counts as one work and adds its item-price sum as revenue.
          for (final t in allTrials) {
            if (t.status.toLowerCase() == 'cancelled') continue;
            if (t.trialDate.isBefore(fyStart) || t.trialDate.isAfter(fyEnd)) {
              continue;
            }
            final m = t.trialDate.month;
            final qi = quarterIndexForMonth(m);
            final amount =
                t.trialItems.fold<double>(0, (s, i) => s + i.price);
            qWorks[qi] += 1;
            qRevenue[qi] += amount;
            if (t.status.toLowerCase() == 'completed') qCompleted[qi] += 1;
            monthWorks[m] = (monthWorks[m] ?? 0) + 1;
            monthRevenue[m] = (monthRevenue[m] ?? 0) + amount;
          }

          final totalWorks = qWorks.fold<int>(0, (s, v) => s + v);
          final totalRevenue = qRevenue.fold<double>(0, (s, v) => s + v);
          final totalAdvance = qAdvance.fold<double>(0, (s, v) => s + v);
          final avgDeal = totalWorks == 0 ? 0.0 : totalRevenue / totalWorks;
          final maxRev = qRevenue.fold<double>(1, (m, v) => v > m ? v : m);

          return ListView(
            padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 28),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  8.w,
                  Text('Quarterly Performance',
                      style: TextStyle(
                          fontSize: isMobile ? 20 : 26,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary)),
                ],
              ),
              4.h,
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                    'FY $financialYear · by ${dateBasis == 'booking_date' ? 'booked date' : 'event date'}',
                    style: TextStyle(fontSize: 13, color: crm.textSecondary)),
              ),
              16.h,
              InvStatGrid(
                isMobile: isMobile,
                stats: [
                  InvStat('$totalWorks', 'Total works',
                      Icons.event_note_outlined, crm.primary),
                  InvStat(_compact(totalRevenue), 'Total revenue',
                      Icons.payments_outlined, const Color(0xFF2E7D32)),
                  InvStat(_compact(totalAdvance), 'Advance collected',
                      Icons.account_balance_wallet_outlined, crm.accent),
                  InvStat(_compact(avgDeal), 'Avg deal size',
                      Icons.trending_up, const Color(0xFF1565C0)),
                ],
              ),
              22.h,
              Text('Revenue by quarter',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary)),
              12.h,
              _revenueBars(crm, qRevenue, maxRev),
              22.h,
              Text('Quarter details',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary)),
              12.h,
              if (isMobile)
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _quarterCard(crm, i, qWorks, qRevenue, qAdvance,
                        qCompleted, qCancelled, monthWorks, monthRevenue),
                  )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.5,
                  children: [
                    for (var i = 0; i < 4; i++)
                      _quarterCard(crm, i, qWorks, qRevenue, qAdvance,
                          qCompleted, qCancelled, monthWorks, monthRevenue),
                  ],
                ),
            ],
          );
        },
    );
  }

  Widget _revenueBars(CrmTheme crm, List<double> qRevenue, double maxRev) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Text(_compact(qRevenue[i]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      6.h,
                      Expanded(
                        child: FractionallySizedBox(
                          alignment: Alignment.bottomCenter,
                          heightFactor: qRevenue[i] == 0
                              ? 0.03
                              : (qRevenue[i] / maxRev)
                                  .clamp(0.05, 1.0)
                                  .toDouble(),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  crm.primary,
                                  crm.primary.withValues(alpha: 0.6),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                      8.h,
                      Text(_quarters[i].$1,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      Text(_quarters[i].$2,
                          style: TextStyle(
                              fontSize: 10, color: crm.textSecondary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quarterCard(
    CrmTheme crm,
    int i,
    List<int> qWorks,
    List<double> qRevenue,
    List<double> qAdvance,
    List<int> qCompleted,
    List<int> qCancelled,
    Map<int, int> monthWorks,
    Map<int, double> monthRevenue,
  ) {
    final q = _quarters[i];
    final balance = qRevenue[i] - qAdvance[i];
    Widget kv(String k, String v, {Color? c}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k.toUpperCase(),
                style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w700,
                    color: crm.textSecondary)),
            2.h,
            Text(v,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c ?? crm.textPrimary)),
          ],
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: crm.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(q.$1,
                    style: TextStyle(
                        color: crm.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ),
              8.w,
              Text(q.$2,
                  style: TextStyle(color: crm.textSecondary, fontSize: 12)),
              const Spacer(),
              Text('${qWorks[i]} works',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: crm.textPrimary)),
            ],
          ),
          12.h,
          Row(children: [
            Expanded(child: kv('Revenue', _compact(qRevenue[i]))),
            Expanded(
                child: kv('Advance', _compact(qAdvance[i]),
                    c: const Color(0xFF2E7D32))),
            Expanded(
                child: kv('Balance', _compact(balance),
                    c: balance > 0 ? crm.destructive : crm.textPrimary)),
          ]),
          10.h,
          Row(children: [
            Expanded(child: kv('Completed', '${qCompleted[i]}')),
            Expanded(child: kv('Cancelled', '${qCancelled[i]}')),
          ]),
          const Divider(height: 22),
          // Month breakdown for this quarter.
          Column(
            children: [
              for (final m in q.$3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(_monthNames[m],
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: crm.textSecondary)),
                      ),
                      Expanded(
                        child: Text('${monthWorks[m] ?? 0} works',
                            style: TextStyle(
                                fontSize: 12, color: crm.textSecondary)),
                      ),
                      Text(_compact(monthRevenue[m] ?? 0),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
