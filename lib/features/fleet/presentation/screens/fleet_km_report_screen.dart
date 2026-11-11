import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart' show formatKm;
import 'package:nizan_crm/features/fleet/data/km_report.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fleet_report_widgets.dart';
import 'package:nizan_crm/presentation/common_widgets/export_report_dialog.dart';

/// Km driven per driver and per vehicle over a chosen date range, from the
/// odometer readings drivers enter at trip start and completion.
class FleetKmReportScreen extends ConsumerStatefulWidget {
  const FleetKmReportScreen({super.key});

  @override
  ConsumerState<FleetKmReportScreen> createState() =>
      _FleetKmReportScreenState();
}

class _FleetKmReportScreenState extends ConsumerState<FleetKmReportScreen> {
  var _preset = FleetRangePreset.thisMonth;
  var _range = fleetRangeFor(FleetRangePreset.thisMonth);

  void _export(KmReport r) {
    showDialog(
      context: context,
      builder: (_) => ExportReportDialog<KmTrip>(
        title: 'Km Report ${fleetDay(_range.from)} - ${fleetDay(_range.to)}',
        items: r.tripList,
        getVehicleName: (t) => t.vehicleName.isEmpty ? null : t.vehicleName,
        getDriverName: (t) => t.driverName.isEmpty ? null : t.driverName,
        headers: const [
          'Completed',
          'Booking',
          'Customer',
          'Driver',
          'Vehicle',
          'Start km',
          'End km',
          'Km driven',
        ],
        buildRow: (t) => [
          t.completedAt == null
              ? ''
              : DateFormat('yyyy-MM-dd HH:mm').format(t.completedAt!),
          t.bookingNumber,
          t.customerName,
          t.driverName,
          [t.vehicleName, t.registrationNumber]
              .where((s) => s.isNotEmpty)
              .join(' '),
          t.startKm.toString(),
          t.endKm.toString(),
          t.km.toStringAsFixed(1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(kmReportProvider(_range));

    final body = ListView(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 0, 12, isMobile ? 16 : 0, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Km Report',
                      style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary)),
                  Text('Who drove the most — from trip odometer readings',
                      style: TextStyle(fontSize: 13, color: crm.textSecondary)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(kmReportProvider(_range)),
              icon: Icon(Icons.refresh_rounded, color: crm.textSecondary),
            ),
            const SizedBox(width: 4),
            OutlinedButton.icon(
              onPressed: () => context.go('/fleet/gps-check'),
              icon: const Icon(Icons.satellite_alt_rounded, size: 18),
              label: Text(isMobile ? 'GPS' : 'Check with GPS'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: async.value == null || async.value!.tripList.isEmpty
                  ? null
                  : () => _export(async.value!),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(isMobile ? 'Export' : 'Export trips'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FleetDateRangeBar(
          preset: _preset,
          range: _range,
          onChanged: (p, r) => setState(() {
            _preset = p;
            _range = r;
          }),
        ),
        const SizedBox(height: 14),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppErrorView(
              error: e, onRetry: () => ref.invalidate(kmReportProvider(_range))),
          data: (r) => _ReportBody(report: r, wide: !isMobile),
        ),
      ],
    );

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(kmReportProvider(_range)),
      child: body,
    );
  }
}

class _ReportBody extends StatelessWidget {
  final KmReport report;
  final bool wide;
  const _ReportBody({required this.report, required this.wide});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = report;
    final top = r.drivers.isEmpty ? null : r.drivers.first;

    final drivers = FleetSection(
      title: 'Drivers by km',
      subtitle: 'Most km first',
      icon: Icons.emoji_events_outlined,
      child: r.drivers.isEmpty
          ? const _Empty('No driver trips with km in this range.')
          : Column(
              children: [
                for (var i = 0; i < r.drivers.length; i++)
                  _RankRow(
                    rank: i + 1,
                    title: r.drivers[i].name.isEmpty
                        ? 'Unknown driver'
                        : r.drivers[i].name,
                    subtitle:
                        '${r.drivers[i].trips} trip${r.drivers[i].trips == 1 ? '' : 's'}',
                    km: r.drivers[i].km,
                    maxKm: r.drivers.first.km,
                  ),
              ],
            ),
    );

    final vehicles = FleetSection(
      title: 'Vehicles by km',
      subtitle: 'Fuel ₹/km uses fuel expenses in the same dates',
      icon: Icons.directions_car_outlined,
      child: r.vehicles.isEmpty
          ? const _Empty('No vehicle trips with km in this range.')
          : Column(
              children: [
                for (var i = 0; i < r.vehicles.length; i++)
                  _RankRow(
                    rank: i + 1,
                    title: [r.vehicles[i].name, r.vehicles[i].registrationNumber]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    subtitle: [
                      '${r.vehicles[i].trips} trip${r.vehicles[i].trips == 1 ? '' : 's'}',
                      if (r.vehicles[i].fuelSpend > 0)
                        'fuel ${fleetInr(r.vehicles[i].fuelSpend)}',
                      if (r.vehicles[i].costPerKm != null)
                        '₹${r.vehicles[i].costPerKm!.toStringAsFixed(1)}/km',
                    ].join(' · '),
                    km: r.vehicles[i].km,
                    maxKm: r.vehicles.first.km,
                  ),
              ],
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FleetKpiGrid(kpis: [
          FleetKpi('${formatKm(r.totalKm)} km', 'Total driven',
              'across all trips', Icons.speed_rounded, crm.primary),
          FleetKpi('${r.trips}', 'Trips with km',
              r.untrackedTrips > 0 ? '+${r.untrackedTrips} without km' : 'all trips tracked',
              Icons.route_rounded, crm.accent),
          FleetKpi('${formatKm(r.avgKmPerTrip)} km', 'Average per trip', '',
              Icons.timeline_rounded, crm.success),
          FleetKpi(
              top == null ? '—' : top.name,
              'Top driver',
              top == null ? 'no trips yet' : '${formatKm(top.km)} km',
              Icons.emoji_events_rounded,
              const Color(0xFFC9A227)),
        ]),
        if (r.untrackedTrips > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: crm.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crm.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: crm.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${r.untrackedTrips} completed trip${r.untrackedTrips == 1 ? ' has' : 's have'} '
                    'no km recorded (started before km tracking) and '
                    '${r.untrackedTrips == 1 ? "isn't" : "aren't"} counted.',
                    style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: drivers),
              const SizedBox(width: 14),
              Expanded(child: vehicles),
            ],
          )
        else ...[
          drivers,
          const SizedBox(height: 14),
          vehicles,
        ],
        const SizedBox(height: 14),
        FleetSection(
          title: 'Trip log',
          subtitle: '${r.tripList.length} trip${r.tripList.length == 1 ? '' : 's'} · newest first',
          icon: Icons.list_alt_rounded,
          child: r.tripList.isEmpty
              ? const _Empty('No completed trips with km in this range.')
              : Column(
                  children: [
                    for (final t in r.tripList) _TripRow(trip: t, wide: wide),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Leaderboard row: rank badge, name, bar scaled to the leader, km.
class _RankRow extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final double km;
  final double maxKm;
  const _RankRow({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.km,
    required this.maxKm,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    const medals = [Color(0xFFC9A227), Color(0xFF9E9E9E), Color(0xFFB0703C)];
    final badge = rank <= 3 ? medals[rank - 1] : crm.textSecondary;
    final frac = maxKm <= 0 ? 0.0 : (km / maxKm).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badge.withValues(alpha: rank <= 3 ? 0.18 : 0.08),
              shape: BoxShape.circle,
            ),
            child: Text('$rank',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: rank <= 3 ? badge : crm.textSecondary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary)),
                    ),
                    Text('${formatKm(km)} km',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: crm.primary)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 6,
                    backgroundColor: crm.input,
                    valueColor: AlwaysStoppedAnimation(crm.primary),
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final KmTrip trip;
  final bool wide;
  const _TripRow({required this.trip, required this.wide});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final t = trip;
    final when = t.completedAt == null
        ? ''
        : DateFormat('d MMM, h:mm a').format(t.completedAt!);
    final vehicle =
        [t.vehicleName, t.registrationNumber].where((s) => s.isNotEmpty).join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: crm.input,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    [
                      if (t.bookingNumber.isNotEmpty) '#${t.bookingNumber}',
                      t.customerName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: crm.textPrimary)),
                const SizedBox(height: 2),
                Text(
                    [
                      if (t.driverName.isNotEmpty) t.driverName,
                      if (vehicle.isNotEmpty) vehicle,
                      if (when.isNotEmpty) when,
                    ].join(' · '),
                    maxLines: wide ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                if (!wide)
                  Text('${formatKm(t.startKm)} → ${formatKm(t.endKm)} km',
                      style:
                          TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          if (wide) ...[
            SizedBox(
              width: 180,
              child: Text('${formatKm(t.startKm)} → ${formatKm(t.endKm)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ),
            const SizedBox(width: 16),
          ],
          SizedBox(
            width: 84,
            child: Text('${formatKm(t.km)} km',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: crm.primary)),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12.5, color: context.crmColors.textSecondary)),
        ),
      );
}
