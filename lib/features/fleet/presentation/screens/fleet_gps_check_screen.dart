import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart' show FleetDateRange;
import 'package:nizan_crm/features/fleet/controllers/gps_km_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart' show formatKm;
import 'package:nizan_crm/features/fleet/data/gps_km.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fleet_report_widgets.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/gps_upload.dart';
import 'package:nizan_crm/presentation/common_widgets/export_report_dialog.dart';

final _dayFmt = DateFormat('EEE, d MMM');

/// Colour of a day's result: green matches, amber under-entered, red the rest.
Color gpsStatusColor(CrmTheme crm, GpsDayStatus s) => switch (s) {
      GpsDayStatus.ok => crm.success,
      GpsDayStatus.driverLow => crm.warning,
      GpsDayStatus.driverHigh => crm.destructive,
      GpsDayStatus.noTrip => crm.destructive,
      GpsDayStatus.noGps => crm.textSecondary,
    };

Color _accuracyColor(CrmTheme crm, double? pct) => pct == null
    ? crm.textSecondary
    : pct >= 90
        ? crm.success
        : pct >= 75
            ? crm.warning
            : crm.destructive;

String _pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}%';

/// What the GPS tracker says a vehicle drove, against the km the drivers entered.
/// The tracker's day-wise report is uploaded here as an Excel / CSV file.
class FleetGpsCheckScreen extends ConsumerStatefulWidget {
  const FleetGpsCheckScreen({super.key});

  @override
  ConsumerState<FleetGpsCheckScreen> createState() => _FleetGpsCheckScreenState();
}

enum _DayFilter { review, all, matches, noData }

class _FleetGpsCheckScreenState extends ConsumerState<FleetGpsCheckScreen> {
  var _preset = FleetRangePreset.custom;

  /// Null = let the server pick the days of the latest upload.
  FleetDateRange? _range;
  var _filter = _DayFilter.review;

  GpsCheckQuery get _query => (from: _range?.from, to: _range?.to);

  Future<void> _upload() async {
    final result = await pickAndUploadGpsReport(context, ref);
    if (result == null || !mounted) return;
    final from = result.from, to = result.to;
    setState(() {
      // show the days that were just uploaded
      _range = from != null && to != null ? (from: from, to: to) : null;
      _preset = FleetRangePreset.custom;
      _filter = _DayFilter.review;
    });
    ref.invalidate(gpsCheckProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(gpsUploadSummary(result))));
  }

  void _export(GpsCheck r) {
    final f = DateFormat('yyyy-MM-dd');
    showDialog(
      context: context,
      builder: (_) => ExportReportDialog<GpsDay>(
        title: 'GPS Km Check ${fleetDay(r.from)} - ${fleetDay(r.to)}',
        items: r.days,
        getVehicleName: (d) => d.vehicleLabel.isEmpty ? null : d.vehicleLabel,
        getDriverName: (d) => d.driverNames.isEmpty ? null : d.driverNames.join(', '),
        headers: const [
          'Date', 'Vehicle', 'Driver', 'GPS km', 'Driver km', 'Way home (est.)',
          'Difference km', 'Difference %', 'Result',
        ],
        buildRow: (d) => [
          f.format(d.date),
          d.vehicleLabel,
          d.driverNames.join(', '),
          d.gpsKm?.toStringAsFixed(1) ?? '',
          d.driverKm?.toStringAsFixed(1) ?? '',
          d.returnLegKm > 0 ? d.returnLegKm.toStringAsFixed(1) : '',
          d.diffKm?.toStringAsFixed(1) ?? '',
          d.diffPct?.toStringAsFixed(1) ?? '',
          d.status.label,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(gpsCheckProvider(_query));
    final data = async.value;

    final body = ListView(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 0, 12, isMobile ? 16 : 0, 24),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GPS Km Check',
                  style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              Text('Are the km drivers enter true? Checked against your GPS tracker',
                  style: TextStyle(fontSize: 13, color: crm.textSecondary)),
            ]),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(gpsCheckProvider(_query)),
            icon: Icon(Icons.refresh_rounded, color: crm.textSecondary),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: _upload,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Upload GPS report'),
          ),
          FilledButton.tonalIcon(
            onPressed: data == null || data.days.isEmpty ? null : () => _export(data),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(isMobile ? 'Export' : 'Export days'),
          ),
        ]),
        if (data != null && data.uploads.isNotEmpty) ...[
          const SizedBox(height: 10),
          _LastUpload(upload: data.uploads.first, more: data.uploads.length - 1),
        ],
        const SizedBox(height: 14),
        if (data != null && data.hasUploads)
          FleetDateRangeBar(
            preset: _preset,
            range: _range ?? (from: data.from, to: data.to),
            onChanged: (p, r) => setState(() {
              _preset = p;
              _range = r;
            }),
          ),
        if (data != null && data.hasUploads) const SizedBox(height: 14),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(gpsCheckProvider(_query))),
          data: (r) => r.hasUploads
              ? _Body(
                  check: r,
                  wide: !isMobile,
                  filter: _filter,
                  onFilter: (f) => setState(() => _filter = f),
                )
              : _NothingYet(onUpload: _upload),
        ),
      ],
    );

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(gpsCheckProvider(_query)),
      child: body,
    );
  }
}

class _LastUpload extends StatelessWidget {
  final GpsUploadInfo upload;
  final int more;
  const _LastUpload({required this.upload, required this.more});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final f = DateFormat('d MMM');
    final days = upload.from != null && upload.to != null ? '${f.format(upload.from!)} – ${f.format(upload.to!)}' : '';
    final when = upload.uploadedAt == null ? '' : DateFormat('d MMM, h:mm a').format(upload.uploadedAt!);
    return Row(children: [
      Icon(Icons.history_rounded, size: 16, color: crm.textSecondary),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          [
            'Last upload: ${upload.fileName.isEmpty ? 'GPS report' : upload.fileName}',
            if (days.isNotEmpty) days,
            if (when.isNotEmpty) when,
            if (upload.uploadedByName.isNotEmpty) 'by ${upload.uploadedByName}',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: crm.textSecondary),
        ),
      ),
    ]);
  }
}

/// Nothing uploaded yet: say how to get the file.
class _NothingYet extends StatelessWidget {
  final VoidCallback onUpload;
  const _NothingYet({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return FleetSection(
      title: 'Upload your GPS km report',
      subtitle: 'To check the km your drivers enter',
      icon: Icons.satellite_alt_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'In your GPS tracking app, open the day-wise distance report for your vehicles, '
          'choose the dates, and export it as Excel. Upload that file here — the app then compares '
          "each day's GPS km with the km the driver entered for that vehicle, and shows where they differ.",
          style: TextStyle(fontSize: 13, height: 1.45, color: crm.textPrimary),
        ),
        const SizedBox(height: 10),
        Text(
          'It needs a vehicle number, a date and a distance for each row. You can upload a new report '
          'every month, or overlapping ones — days that are already saved are simply updated.',
          style: TextStyle(fontSize: 12.5, height: 1.45, color: crm.textSecondary),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onUpload,
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: const Text('Upload GPS report'),
        ),
      ]),
    );
  }
}

class _Body extends StatelessWidget {
  final GpsCheck check;
  final bool wide;
  final _DayFilter filter;
  final ValueChanged<_DayFilter> onFilter;
  const _Body({required this.check, required this.wide, required this.filter, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final t = check.totals;

    final vehicles = FleetSection(
      title: 'Vehicles',
      subtitle: 'Least accurate first',
      icon: Icons.directions_car_outlined,
      child: check.vehicles.isEmpty
          ? const _Empty('No vehicle has both GPS and driver km in this range.')
          : Column(children: [for (final v in check.vehicles) _StandingRow(standing: v, vehicle: true)]),
    );
    final drivers = FleetSection(
      title: 'Drivers',
      subtitle: 'Only days they had the vehicle to themselves',
      icon: Icons.badge_outlined,
      child: check.drivers.isEmpty
          ? const _Empty('No driver can be judged yet.')
          : Column(children: [for (final d in check.drivers) _StandingRow(standing: d, vehicle: false)]),
    );

    final shown = check.days.where((d) => switch (filter) {
          _DayFilter.review => d.status.needsReview,
          _DayFilter.all => true,
          _DayFilter.matches => d.status == GpsDayStatus.ok,
          _DayFilter.noData => d.status == GpsDayStatus.noGps,
        }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FleetKpiGrid(kpis: [
        FleetKpi(
          _pct(t.accuracyPct),
          'Km accuracy',
          t.comparedDays == 0 ? 'nothing to compare' : '${t.comparedDays} day${t.comparedDays == 1 ? '' : 's'} compared',
          Icons.verified_outlined,
          _accuracyColor(crm, t.accuracyPct),
        ),
        FleetKpi(
          '${formatKm(t.comparedGpsKm)} km',
          'GPS km',
          'drivers: ${formatKm(t.comparedDriverKm)} km',
          Icons.satellite_alt_rounded,
          crm.primary,
        ),
        FleetKpi(
          '${t.reviewDays}',
          'To review',
          t.reviewDays == 0
              ? 'all clear'
              : [
                  if (t.lowDays > 0) '${t.lowDays} low',
                  if (t.highDays > 0) '${t.highDays} high',
                  if (t.noTripDays > 0) '${t.noTripDays} no trip',
                  if (t.noGpsDays > 0) '${t.noGpsDays} no data',
                ].join(' · '),
          Icons.flag_outlined,
          t.reviewDays == 0 ? crm.success : crm.warning,
        ),
        FleetKpi(
          '${formatKm(t.unloggedKm)} km',
          'Unlogged km',
          '${t.noTripDays} day${t.noTripDays == 1 ? '' : 's'}, no trip',
          Icons.help_outline_rounded,
          t.unloggedKm > 0 ? crm.destructive : crm.success,
        ),
      ]),
      const SizedBox(height: 10),
      _HowItWorks(check: check),
      const SizedBox(height: 14),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: vehicles),
          const SizedBox(width: 14),
          Expanded(child: drivers),
        ])
      else ...[
        vehicles,
        const SizedBox(height: 14),
        drivers,
      ],
      const SizedBox(height: 14),
      FleetSection(
        title: 'Day by day',
        subtitle: '${shown.length} of ${check.days.length} day${check.days.length == 1 ? '' : 's'} · newest first',
        icon: Icons.fact_check_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final f in _DayFilter.values)
              ChoiceChip(
                label: Text(switch (f) {
                  _DayFilter.review => 'Needs review (${t.reviewDays})',
                  _DayFilter.all => 'All (${check.days.length})',
                  _DayFilter.matches => 'Matches (${t.okDays})',
                  _DayFilter.noData => 'No GPS data (${t.noGpsDays})',
                }),
                selected: filter == f,
                onSelected: (_) => onFilter(f),
              ),
          ]),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            _Empty(filter == _DayFilter.review ? 'Nothing to review in this range.' : 'No days here.')
          else
            for (final d in shown) _DayRow(day: d, wide: wide),
        ]),
      ),
      if (check.vehiclesWithoutGps.isNotEmpty || check.unmatchedGps.isNotEmpty) ...[
        const SizedBox(height: 14),
        _Notes(check: check),
      ],
    ]);
  }
}

class _HowItWorks extends StatelessWidget {
  final GpsCheck check;
  const _HowItWorks({required this.check});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.primary.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, size: 18, color: crm.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "How a day is judged: the driver's odometer km (trip end − start) plus the drive back to the office, "
            "which no trip records but GPS does, against the GPS km. Within ${check.tolerancePercent.round()}% "
            "(at least ${check.toleranceMinKm.round()} km) counts as a match. "
            'Accuracy = 100% minus all the differences, in either direction, as a share of the GPS km.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: crm.textPrimary),
          ),
        ),
      ]),
    );
  }
}

/// A vehicle or a driver: accuracy bar and what the days came to.
class _StandingRow extends StatelessWidget {
  final GpsStanding standing;
  final bool vehicle;
  const _StandingRow({required this.standing, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final s = standing;
    final color = _accuracyColor(crm, s.accuracyPct);
    final detail = [
      '${s.comparedDays} day${s.comparedDays == 1 ? '' : 's'} compared',
      if (s.okDays > 0) '${s.okDays} match',
      if (s.lowDays > 0) '${s.lowDays} low',
      if (s.highDays > 0) '${s.highDays} high',
      if (vehicle && s.noTripDays > 0) '${s.noTripDays} no trip (${formatKm(s.unloggedKm)} km)',
      if (vehicle && s.noGpsDays > 0) '${s.noGpsDays} no data',
    ].join(' · ');
    final net = s.netDiffKm;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(vehicle ? (s.label.isEmpty ? 'Vehicle' : s.label) : (s.name.isEmpty ? 'Unknown driver' : s.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
          ),
          Text(_pct(s.accuracyPct), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ((s.accuracyPct ?? 0) / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: crm.input,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 3),
        Text(detail, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        if (s.comparedDays > 0 && net.abs() >= 1)
          Text(
            net > 0
                ? 'GPS shows ${formatKm(net)} km more than was entered'
                : 'Entered ${formatKm(-net)} km more than GPS shows',
            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
          ),
      ]),
    );
  }
}

String _verdict(GpsDay d) {
  final tol = d.toleranceKm == null ? '' : ' (allowed ±${formatKm(d.toleranceKm!)} km)';
  final diff = d.diffKm ?? 0;
  return switch (d.status) {
    GpsDayStatus.ok => 'Within ±${formatKm(d.toleranceKm ?? 0)} km of GPS',
    GpsDayStatus.driverLow => 'GPS shows ${formatKm(diff)} km more than the driver entered$tol',
    GpsDayStatus.driverHigh => 'The driver entered ${formatKm(-diff)} km more than GPS shows$tol',
    GpsDayStatus.noTrip => 'The vehicle moved ${formatKm(d.gpsKm ?? 0)} km but no driver km was entered for it',
    GpsDayStatus.noGps => d.reason == 'zero'
        ? 'The tracker showed almost no movement although ${formatKm(d.driverKm ?? 0)} km were entered — it may have been off'
        : 'The GPS report has no row for this day, so it cannot be checked',
  };
}

class _DayRow extends StatefulWidget {
  final GpsDay day;
  final bool wide;
  const _DayRow({required this.day, required this.wide});

  @override
  State<_DayRow> createState() => _DayRowState();
}

class _DayRowState extends State<_DayRow> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final d = widget.day;
    final color = gpsStatusColor(crm, d.status);
    final drivers = d.driverNames.join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: crm.input, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Container(width: 4, height: 38, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_dayFmt.format(d.date),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                  Text(
                    [d.vehicleLabel, if (drivers.isNotEmpty) drivers].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                  ),
                  Text(
                    'GPS ${d.gpsKm == null ? '—' : '${formatKm(d.gpsKm!)} km'}'
                    ' · Driver ${d.driverKm == null ? '—' : '${formatKm(d.driverKm!)} km'}'
                    '${d.returnLegKm > 0 ? ' + ${formatKm(d.returnLegKm)} home' : ''}',
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text(d.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                ),
                if (d.diffKm != null && d.status.compared)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${d.diffKm! > 0 ? '+' : ''}${formatKm(d.diffKm!)} km',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
                    ),
                  ),
              ]),
              Icon(_open ? Icons.expand_less : Icons.expand_more, size: 20, color: crm.textSecondary),
            ]),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 0, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_verdict(d), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary)),
              const SizedBox(height: 6),
              if (d.trips.isEmpty)
                Text('No completed trips with km on this day.', style: TextStyle(fontSize: 12, color: crm.textSecondary))
              else
                for (final t in d.trips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${[
                        if (t.bookingNumber.isNotEmpty) '#${t.bookingNumber}',
                        if (t.customerName.isNotEmpty) t.customerName,
                      ].join(' · ')}  —  ${formatKm(t.startKm)} → ${formatKm(t.endKm)} = ${formatKm(t.km)} km',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary),
                    ),
                  ),
              if (d.returnLegKm > 0)
                Text(
                  'Way back to the office ≈ ${formatKm(d.returnLegKm)} km '
                  '(${d.returnLegSource == 'route' ? "from the day's route" : "the work's own distance"}) — not on any odometer entry.',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
              if (d.runningHours != null)
                Text(
                  'GPS: moving ${d.runningHours!.toStringAsFixed(1)} h'
                  '${d.stopHours == null ? '' : ' · stopped ${d.stopHours!.toStringAsFixed(1)} h'}'
                  '${d.idleHours == null ? '' : ' · idle ${d.idleHours!.toStringAsFixed(1)} h'}',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
              if (d.startAddress.isNotEmpty)
                Text(
                  d.endAddress.isNotEmpty && d.endAddress != d.startAddress
                      ? 'From ${d.startAddress} to ${d.endAddress}'
                      : 'Around ${d.startAddress}',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _Notes extends StatelessWidget {
  final GpsCheck check;
  const _Notes({required this.check});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final lines = <String>[
      for (final v in check.vehiclesWithoutGps)
        '${[v.name, v.registrationNumber].where((s) => s.isNotEmpty).join(' · ')} has ${v.trips} trip${v.trips == 1 ? '' : 's'} '
            '(${formatKm(v.driverKm)} km) but is not in the GPS report, so its km cannot be checked.',
      for (final u in check.unmatchedGps)
        '${u.registrationNumber} is in the GPS report (${u.days} day${u.days == 1 ? '' : 's'}, ${formatKm(u.gpsKm)} km) '
            'but is not one of your vehicles. It will be checked once you add it.',
    ];
    return FleetSection(
      title: 'Not checked',
      icon: Icons.rule_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 15, color: crm.warning),
              const SizedBox(width: 6),
              Expanded(child: Text(l, style: TextStyle(fontSize: 12.5, color: crm.textPrimary))),
            ]),
          ),
      ]),
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
          child: Text(text, style: TextStyle(fontSize: 12.5, color: context.crmColors.textSecondary)),
        ),
      );
}
