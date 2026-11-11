import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';

// A driver's day: several trips, one pre-trip inspection. The first trip is
// started from the inspection screen; every later trip that day only needs
// its starting km (or starts automatically when the previous one completes).

const _notStarted = {'unassigned', 'assigned', 'inspection_pending'};

bool isNotStarted(FleetJob j) => _notStarted.contains(j.tripStatus);

bool _isToday(DateTime d) {
  final l = d.toLocal();
  final n = DateTime.now();
  return l.year == n.year && l.month == n.month && l.day == n.day;
}

bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// Today's trips, in time order (completed ones included).
List<FleetJob> todaysTrips(List<FleetJob> jobs) =>
    jobs.where((j) => _isToday(j.serviceStart)).toList()
      ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));

/// The trip running right now, if any.
FleetJob? activeTrip(List<FleetJob> jobs) =>
    jobs.where((j) => j.tripStatus == 'in_progress').firstOrNull;

/// The day's inspection is done once any trip was started today.
bool inspectedToday(List<FleetJob> jobs) =>
    jobs.any((j) => j.tripStartedAt != null && _isToday(j.tripStartedAt!));

/// The earliest not-started trip on the same day as [current].
FleetJob? nextTripAfter(List<FleetJob> jobs, FleetJob current) {
  final list = jobs
      .where((j) =>
          j.id != current.id &&
          isNotStarted(j) &&
          _sameDay(j.serviceStart, current.serviceStart))
      .toList()
    ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));
  return list.firstOrNull;
}

String vehicleIdOf(FleetJob j) {
  final v = j.vehicleId;
  if (v is Map) return (v['_id'] ?? '').toString();
  return (v ?? '').toString();
}

String vehicleLabelOf(FleetJob j) {
  final v = j.vehicleId;
  if (v is Map) {
    return [v['type'], v['registrationNumber']]
        .where((s) => s != null && '$s'.isNotEmpty)
        .join(' · ');
  }
  return '';
}

/// True when [a] and [b] use the same vehicle (or either has none set), so
/// the odometer carries straight over from one to the other.
bool sameVehicle(FleetJob a, FleetJob b) {
  final x = vehicleIdOf(a), y = vehicleIdOf(b);
  return x.isEmpty || y.isEmpty || x == y;
}

/// Best guess for a trip's starting km: where the same vehicle ended its last
/// trip today, else the vehicle's last recorded reading.
double? suggestedStartKm(List<FleetJob> jobs, FleetJob job) {
  final done = jobs
      .where((j) =>
          j.endKm != null &&
          j.tripCompletedAt != null &&
          _isToday(j.tripCompletedAt!) &&
          sameVehicle(j, job))
      .toList()
    ..sort((a, b) => b.tripCompletedAt!.compareTo(a.tripCompletedAt!));
  if (done.isNotEmpty) return done.first.endKm;
  final km = job.vehicleCurrentKm;
  return km > 0 ? km : null;
}

/// What tapping "Start" on a not-started trip does: the inspection screen for
/// the first trip of the day, otherwise a quick km-only start.
Future<void> startTrip(BuildContext context, WidgetRef ref, FleetJob job) async {
  final jobs = ref.read(driverJobsProvider).value ?? const <FleetJob>[];
  final running = activeTrip(jobs);
  if (running != null && running.id != job.id) {
    showWarningSnackBar(context,
        'Complete your current trip (${running.customerName}) first.');
    return;
  }
  if (!inspectedToday(jobs)) {
    context.push('/driver/inspection/${job.id}');
    return;
  }
  final started = await showQuickStartSheet(context, ref, job,
      suggestedKm: suggestedStartKm(jobs, job));
  if (started && context.mounted) {
    context.push('/driver/active_job/${job.id}');
  }
}

/// Bottom sheet: the trip's details + starting km, then starts it. Returns
/// true when the trip was started.
Future<bool> showQuickStartSheet(
  BuildContext context,
  WidgetRef ref,
  FleetJob job, {
  double? suggestedKm,
}) async {
  final kmCtrl = TextEditingController(
      text: suggestedKm == null ? '' : formatKm(suggestedKm).replaceAll(',', ''));
  // The artist OTP is no longer asked at start — the driver verifies it on
  // the trip screen once the artist is in the car (needed before closing).
  final requiresOtp = job.requiresArtistOtp;
  String? error;
  var busy = false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        Future<void> go() async {
          final km = double.tryParse(kmCtrl.text.replaceAll(',', '').trim());
          if (km == null || km < 0) {
            setSheet(() => error = 'Enter the starting km reading');
            return;
          }
          setSheet(() {
            busy = true;
            error = null;
          });
          try {
            await ref.read(fleetServiceProvider).startNextTrip(
                  job.id,
                  startKm: km,
                );
            ref.refreshData
              ..fleetJobs()
              ..bookings();
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (e) {
            setSheet(() {
              busy = false;
              error = friendlyErrorMessage(e);
            });
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 14, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Start next trip',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                requiresOtp
                    ? "Confirm the km. Enter the artist's OTP on the trip screen once they're in the car."
                    : "Today's inspection is done — just confirm the km.",
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              NextTripCard(job: job),
              const SizedBox(height: 16),
              TextField(
                controller: kmCtrl,
                autofocus: suggestedKm == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Starting km',
                  suffixText: 'km',
                  errorText: error,
                  helperText: suggestedKm == null
                      ? null
                      : 'Filled from the last reading — change it if different',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : go,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4A1942),
                    minimumSize: const Size(0, 50),
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start trip',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  kmCtrl.dispose();
  return result == true;
}

/// Compact summary of a trip: customer, time, service, address, vehicle.
class NextTripCard extends StatelessWidget {
  final FleetJob job;
  final String? label;
  const NextTripCard({super.key, required this.job, this.label});

  @override
  Widget build(BuildContext context) {
    final t = job.serviceStart.toLocal();
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final time = '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
    final vehicle = vehicleLabelOf(job);
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[800])),
              ),
            ],
          ),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4A1942).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A1942).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Text(label!.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF4A1942))),
          Text('${job.customerName} · $time',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          line(Icons.design_services_outlined, job.service),
          if ((job.address ?? '').isNotEmpty)
            line(Icons.location_on_outlined, job.address!),
          if (vehicle.isNotEmpty) line(Icons.directions_car_outlined, vehicle),
        ],
      ),
    );
  }
}
