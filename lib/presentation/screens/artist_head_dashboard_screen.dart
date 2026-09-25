import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/salary_controller.dart';
import 'package:nizan_crm/features/reviews/services/review_service.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/core/models/employee.dart';

/// Artist Head dashboard — org-wide overview (KPIs, lead/utilization charts,
/// bookings, top artists). Data from existing providers; region scoping + the
/// no-data widgets (masterclass, onboarding) are later phases.
class ArtistHeadDashboardScreen extends ConsumerWidget {
  const ArtistHeadDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final name = ref.watch(authSessionProvider)?.name ?? 'there';

    final bookingsAsync = ref.watch(bookingProvider);
    final leadsAsync = ref.watch(leadsProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final salariesAsync = ref.watch(salariesProvider);
    final bookings = bookingsAsync.value ?? const <Booking>[];
    final leads = leadsAsync.value ?? const [];
    final employees = employeesAsync.value ?? const <Employee>[];
    final salResult = salariesAsync.value;
    final reviewsAsync = ref.watch(reviewAnalyticsProvider);
    // Without this, a failed load just shows zeros that look like real data.
    final loadError = bookingsAsync.error ??
        leadsAsync.error ??
        employeesAsync.error ??
        salariesAsync.error;

    // ── Artists ──
    final artists = employees
        .where((e) => e.isArtist && e.status.toLowerCase() == 'active')
        .toList();
    final inHouse = artists.where((e) => e.type == 'in-house').length;

    // ── Bookings ──
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;
    String st(Booking b) => b.status.toLowerCase();
    final activeBookings =
        bookings.where((b) => st(b) != 'completed' && st(b) != 'cancelled');
    final active = activeBookings.length;
    final today = bookings.where((b) => isToday(b.serviceStart)).toList();
    final completed = bookings.where((b) => st(b) == 'completed').length;
    final inProgress = bookings.where((b) => st(b) == 'confirmed').length;
    final upcoming = bookings
        .where((b) => st(b) == 'pending' && b.serviceStart.isAfter(now))
        .length;
    final cancelled = bookings.where((b) => st(b) == 'cancelled').length;

    // ── Utilization: active artists with ≥1 active assignment ──
    final busyArtistIds = <String>{};
    for (final b in activeBookings) {
      for (final s in b.assignedStaff) {
        if (s.roleType != 'driver') busyArtistIds.add(s.employeeId);
      }
    }
    final utilPct = artists.isEmpty
        ? 0
        : ((busyArtistIds.where((id) => artists.any((a) => a.id == id)).length /
                    artists.length) *
                100)
            .round();

    // ── Leads ──
    String lstatus(dynamic l) => (l.status as String? ?? '').toLowerCase();
    final newLeads = leads.where((l) => lstatus(l) == 'new').length;
    final followUp = leads.where((l) => lstatus(l).contains('follow')).length;
    final inDiscussion =
        leads.where((l) => lstatus(l).contains('discuss')).length;
    final converted = leads.where((l) => lstatus(l).contains('convert')).length;
    final lost = leads.where((l) => lstatus(l).contains('lost')).length;
    final shortlisted =
        leads.where((l) => lstatus(l).contains('shortlist')).length;

    // Lead-conversion proximity, derived from lead stage.
    final proximity = <_Seg>[
      _Seg('High (likely)', converted, const Color(0xFF16A34A)),
      _Seg('Medium (in discussion)', inDiscussion + followUp, const Color(0xFFF59E0B)),
      _Seg('Low (early stage)', newLeads, const Color(0xFF3B82F6)),
      _Seg('Cold / lost', lost, const Color(0xFFDC2626)),
    ];

    // Leads by source.
    final bySource = <String, int>{};
    for (final l in leads) {
      final s = (l.source as String?)?.trim();
      final key = (s == null || s.isEmpty) ? 'Other' : s;
      bySource[key] = (bySource[key] ?? 0) + 1;
    }
    final sourcePalette = const [
      Color(0xFF6D5DF6), Color(0xFF16A34A), Color(0xFFF59E0B),
      Color(0xFFDB2777), Color(0xFF0EA5E9), Color(0xFF9CA3AF),
    ];
    final sourceSegs = <_Seg>[];
    var pi = 0;
    for (final e in (bySource.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))) {
      sourceSegs.add(_Seg(e.key, e.value, sourcePalette[pi % sourcePalette.length]));
      pi++;
    }

    final leadsOverview = <_Seg>[
      _Seg('New', newLeads, const Color(0xFFEA580C)),
      _Seg('Shortlisted', shortlisted, const Color(0xFF6D5DF6)),
      _Seg('In discussion', inDiscussion + followUp, const Color(0xFFF59E0B)),
      _Seg('Converted', converted, const Color(0xFF16A34A)),
    ];

    // ── Pending payouts ──
    double pendingPayout = 0;
    int pendingPayoutCount = 0;
    if (salResult != null) {
      for (final s in salResult.salaries) {
        if (s.status != 'paid' && s.status != 'cancelled') {
          pendingPayout += s.netAmount;
          pendingPayoutCount++;
        }
      }
    }

    final recent = [...bookings]
      ..sort((a, b) => (b.createdAt ?? b.bookingDate)
          .compareTo(a.createdAt ?? a.bookingDate));

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(leadsProvider);
          ref.invalidate(employeesProvider);
          ref.invalidate(salariesProvider);
          ref.invalidate(reviewAnalyticsProvider);
        },
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
                      Text('Artist Head Dashboard 👋',
                          style: TextStyle(
                              fontSize: isMobile ? 22 : 28,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      4.gap,
                      Text('Welcome back, $name!',
                          style: TextStyle(color: crm.textSecondary)),
                    ],
                  ),
                ),
                8.wgap,
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/artist-head/artists'),
                  icon: const Icon(Icons.groups_2_outlined, size: 18),
                  label: Text(isMobile ? 'Artists' : 'Manage Artists'),
                ),
              ],
            ),
            18.gap,
            if (loadError != null) ...[
              AppErrorView(
                error: loadError,
                compact: true,
                title: 'Some dashboard data could not be loaded',
                onRetry: () {
                  ref.invalidate(bookingProvider);
                  ref.invalidate(leadsProvider);
                  ref.invalidate(employeesProvider);
                  ref.invalidate(salariesProvider);
                },
              ),
              12.gap,
            ],

            // ── KPI row ──
            _wrap(isMobile, [
              _kpi(crm, Icons.groups_2_outlined, '${artists.length}',
                  'Total Artists',
                  '$inHouse in-house · ${artists.length - inHouse} outsource',
                  const Color(0xFF6D5DF6)),
              _kpi(crm, Icons.event_available_outlined, '$active',
                  'Active Bookings', '${today.length} today',
                  const Color(0xFF16A34A)),
              _kpi(crm, Icons.assignment_turned_in_outlined, '${today.length}',
                  "Today's Assignments", 'across all artists',
                  const Color(0xFFEA580C)),
              _kpi(crm, Icons.person_add_alt_1_outlined, '$newLeads',
                  'New Leads', '$followUp in follow-up',
                  const Color(0xFFDB2777)),
              _kpi(crm, Icons.account_balance_wallet_outlined,
                  '₹${_money(pendingPayout)}', 'Pending Payouts',
                  '$pendingPayoutCount staff', const Color(0xFF7C3AED)),
            ]),
            18.gap,

            // ── Proximity + Utilization ──
            _cols(isMobile, [
              _card(
                crm,
                'Lead Conversion Proximity',
                _donutWithLegend(crm, proximity, '${leads.length}', 'Total Leads'),
              ),
              _card(
                crm,
                'Artist Utilization Rate',
                _gauge(crm, utilPct, artists.length, busyArtistIds),
              ),
            ]),
            14.gap,

            // ── Leads overview + by source + bookings summary ──
            _cols(isMobile, [
              _card(crm, 'Leads Overview',
                  _donutWithLegend(crm, leadsOverview, '${leads.length}', 'Total Leads')),
              _card(crm, 'Leads by Source',
                  _donutWithLegend(crm, sourceSegs, '${leads.length}', 'Total Leads')),
              _card(crm, 'Bookings Summary', _summary(crm, {
                'Total Bookings': bookings.length,
                'Completed': completed,
                'In Progress': inProgress,
                'Upcoming': upcoming,
                'Cancelled': cancelled,
              })),
            ]),
            18.gap,

            // ── Recent bookings + Top artists ──
            _cols(isMobile, [
              _card(crm, 'Recent Bookings', _recentBookings(context, crm, recent)),
              _topArtists(context, crm, employees, reviewsAsync),
            ]),
          ],
        ),
      ),
    );
  }

  // ── layout helpers ──
  Widget _wrap(bool isMobile, List<Widget> items) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final c in items)
            SizedBox(width: isMobile ? double.infinity : 224, child: c),
        ],
      );

  Widget _cols(bool isMobile, List<Widget> items) => isMobile
      ? Column(
          children: [
            for (final c in items)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: c)
          ],
        )
      : IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i < items.length - 1) const SizedBox(width: 14),
              ],
            ],
          ),
        );

  Widget _card(CrmTheme crm, String title, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: crm.textPrimary)),
            14.gap,
            child,
          ],
        ),
      );

  Widget _kpi(CrmTheme crm, IconData icon, String value, String label,
          String sub, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            12.gap,
            Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: crm.textPrimary)),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: crm.textPrimary)),
            2.gap,
            Text(sub, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ],
        ),
      );

  // ── donut with a legend beside it ──
  Widget _donutWithLegend(CrmTheme crm, List<_Seg> segs, String centerValue,
      String centerLabel) {
    final total = segs.fold<int>(0, (s, e) => s + e.value);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 38,
                sections: total == 0
                    ? [
                        PieChartSectionData(
                            value: 1, color: crm.border, radius: 16, showTitle: false)
                      ]
                    : [
                        for (final s in segs)
                          if (s.value > 0)
                            PieChartSectionData(
                                value: s.value.toDouble(),
                                color: s.color,
                                radius: 16,
                                showTitle: false),
                      ],
              )),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(centerValue,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: crm.textPrimary)),
                  Text(centerLabel,
                      style:
                          TextStyle(fontSize: 9, color: crm.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        14.wgap,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in segs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                              color: s.color, shape: BoxShape.circle)),
                      7.wgap,
                      Expanded(
                          child: Text(s.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: crm.textSecondary))),
                      Text('${s.value}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                      6.wgap,
                      Text(
                          total == 0
                              ? '0%'
                              : '${((s.value / total) * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 11, color: crm.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── utilization gauge ──
  Widget _gauge(CrmTheme crm, int pct, int totalArtists, Set<String> busy) {
    final color = pct >= 70
        ? const Color(0xFF16A34A)
        : (pct >= 40 ? const Color(0xFFF59E0B) : const Color(0xFFDC2626));
    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 0,
                centerSpaceRadius: 44,
                sections: [
                  PieChartSectionData(
                      value: pct.toDouble(),
                      color: color,
                      radius: 14,
                      showTitle: false),
                  PieChartSectionData(
                      value: (100 - pct).toDouble(),
                      color: crm.border,
                      radius: 14,
                      showTitle: false),
                ],
              )),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$pct%',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: crm.textPrimary)),
                  Text('Utilization',
                      style:
                          TextStyle(fontSize: 10, color: crm.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        16.wgap,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$totalArtists active artists',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: crm.textPrimary)),
              6.gap,
              Text(
                  '${busy.where((id) => id.isNotEmpty).length} currently on active assignments',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              6.gap,
              Text('Utilization = artists with a live booking ÷ total artists',
                  style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summary(CrmTheme crm, Map<String, int> rows) => Column(
        children: [
          for (final e in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key,
                      style: TextStyle(color: crm.textSecondary, fontSize: 13)),
                  Text('${e.value}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: crm.textPrimary)),
                ],
              ),
            ),
        ],
      );

  Widget _recentBookings(BuildContext context, CrmTheme crm, List<Booking> b) {
    if (b.isEmpty) {
      return Text('No bookings yet.',
          style: TextStyle(color: crm.textSecondary, fontSize: 13));
    }
    return Column(
      children: [
        for (final r in b.take(6))
          InkWell(
            onTap: () => context.push('/booking/manage/${r.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                        r.customerName.isEmpty
                            ? '#${r.displayBookingNumber}'
                            : r.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(_date(r.serviceStart),
                        style: TextStyle(
                            fontSize: 12, color: crm.textSecondary)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _statusColor(r.status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100)),
                    child: Text(r.status,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(r.status))),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _topArtists(BuildContext context, CrmTheme crm,
          List<Employee> employees, AsyncValue<ReviewAnalytics> async) =>
      _card(
        crm,
        'Top Performing Artists',
        async.when(
          loading: () => _muted(crm, 'Loading…'),
          error: (e, _) => AppErrorView(
            error: e,
            compact: true,
            onRetry: () => ProviderScope.containerOf(context, listen: false)
                .invalidate(reviewAnalyticsProvider),
          ),
          data: (a) => a.perArtist.isEmpty
              ? _muted(crm, 'No reviews yet.')
              : Column(
                  children: [
                    for (final s in a.perArtist.take(6))
                      _artistRow(context, crm, employees, s),
                  ],
                ),
        ),
      );

  Widget _artistRow(BuildContext context, CrmTheme crm,
      List<Employee> employees, ArtistStat s) {
    final matches = employees.where(
        (e) => e.name.trim().toLowerCase() == s.artistName.trim().toLowerCase());
    final id = matches.isNotEmpty ? matches.first.id : '';
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(
            child: Text(s.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        Text('${s.count} rev',
            style: TextStyle(fontSize: 11, color: crm.textSecondary)),
        8.wgap,
        Icon(Icons.star_rounded, size: 15, color: crm.primary),
        2.wgap,
        Text('${s.avgTeamScore}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        if (id.isNotEmpty) ...[
          4.wgap,
          Icon(Icons.chevron_right, size: 16, color: crm.textSecondary),
        ],
      ]),
    );
    if (id.isEmpty) return row;
    return InkWell(
      onTap: () => context.push('/artist-head/artist/$id'),
      child: row,
    );
  }

  Widget _muted(CrmTheme crm, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(t, style: TextStyle(color: crm.textSecondary, fontSize: 13)),
      );

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed':
        return const Color(0xFF16A34A);
      case 'confirmed':
        return const Color(0xFF2563EB);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'postponed':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  static const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _date(DateTime d) => '${d.day} ${_mon[d.month]}';
  static String _money(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

class _Seg {
  final String label;
  final int value;
  final Color color;
  const _Seg(this.label, this.value, this.color);
}

extension _G on num {
  Widget get gap => SizedBox(height: toDouble());
  Widget get wgap => SizedBox(width: toDouble());
}
