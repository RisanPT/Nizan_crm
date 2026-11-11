import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'driver_day.dart';

class DriverDashboard extends ConsumerWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(driverJobsProvider);
    final session = ref.watch(authSessionProvider);
    final driverName = session?.name ?? 'Driver';
    final firstName = driverName.split(' ').first;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: RefreshIndicator(
        color: const Color(0xFF4A1942),
        onRefresh: () async => ref.invalidate(driverJobsProvider),
        child: CustomScrollView(
          slivers: [
            _buildSliverHeader(firstName),
            SliverToBoxAdapter(child: _buildTodaySummary(jobsAsync)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  "Today's Assignments",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ),
            jobsAsync.when(
              data: (jobs) {
                // Every trip of the day, in order — completed ones stay so
                // the driver sees the whole day (Trip 1 of 3 …).
                final running = activeTrip(jobs);
                // A running trip always shows here, even when it belongs to
                // another day — e.g. tomorrow's long trip started today.
                final todayJobs = [
                  if (running != null &&
                      !todaysTrips(jobs).any((j) => j.id == running.id))
                    running,
                  ...todaysTrips(jobs),
                ];

                if (todayJobs.isEmpty) {
                  return SliverToBoxAdapter(child: _buildEmptyState());
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildJobCard(ctx, ref, todayJobs[i],
                          index: i,
                          count: todayJobs.length,
                          blockedBy: running != null &&
                                  running.id != todayJobs[i].id &&
                                  isNotStarted(todayJobs[i])
                              ? running
                              : null),
                      childCount: todayJobs.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF4A1942)),
                  ),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: _buildError(ref, err),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader(String firstName) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: false,
      floating: true,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3A0F35), Color(0xFF6B1A5F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.local_shipping_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $firstName 👋',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const Text(
                              'Driver Dashboard',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySummary(AsyncValue<List<FleetJob>> jobsAsync) {
    return jobsAsync.when(
      data: (allJobs) {
        // This summary sits above "Today's Assignments", so count today's
        // jobs only (it used to count every job ever assigned).
        final now = DateTime.now();
        final jobs = allJobs.where((j) {
          final s = j.serviceStart.toLocal();
          return s.year == now.year && s.month == now.month && s.day == now.day;
        }).toList();
        final total = jobs.length;
        final completed = jobs.where((j) => j.tripStatus == 'completed').length;
        final inProgress =
            jobs.where((j) => j.tripStatus == 'in_progress').length;
        final pending = jobs
            .where((j) =>
                j.tripStatus == 'assigned' || j.tripStatus == 'unassigned')
            .length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              _buildStatCard('Total', total.toString(), Icons.list_alt_rounded,
                  const Color(0xFF6C63FF)),
              const SizedBox(width: 10),
              _buildStatCard('Pending', pending.toString(),
                  Icons.schedule_rounded, const Color(0xFFFF9800)),
              const SizedBox(width: 10),
              _buildStatCard('Active', inProgress.toString(),
                  Icons.directions_car_rounded, const Color(0xFF4CAF50)),
              const SizedBox(width: 10),
              _buildStatCard('Done', completed.toString(),
                  Icons.check_circle_rounded, const Color(0xFF2196F3)),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 80),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, WidgetRef ref, FleetJob job,
      {required int index, required int count, FleetJob? blockedBy}) {
    final statusInfo = _getStatusInfo(job.tripStatus);
    final done = job.tripStatus == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isNotStarted(job)) {
            startTrip(context, ref, job);
          } else {
            context.push('/driver/active_job/${job.id}');
          }
        },
        child: Opacity(
          opacity: done ? 0.6 : 1,
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (count > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('TRIP ${index + 1} OF $count',
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Color(0xFF6B1A5F))),
                ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A1942).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: Color(0xFF4A1942),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.customerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        if (job.address != null && job.address!.isNotEmpty)
                          Text(
                            job.address!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (statusInfo['color'] as Color)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusInfo['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusInfo['label'] as String,
                          style: TextStyle(
                            color: statusInfo['color'] as Color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildDetailItem(
                        Icons.design_services_outlined,
                        job.service,
                        const Color(0xFF6C63FF)),
                    const SizedBox(width: 8),
                    _buildDetailItem(
                        Icons.access_time_rounded,
                        _formatDateTime(job.serviceStart),
                        const Color(0xFF2196F3)),
                  ],
                ),
              ),
              if (done && job.tripKm != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.speed_rounded, size: 15, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${formatKm(job.startKm!)} → ${formatKm(job.endKm!)} km · ${formatKm(job.tripKm!)} km driven',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _buildPrimaryButton(context, ref, job, blockedBy: blockedBy),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, WidgetRef ref, FleetJob job,
      {FleetJob? blockedBy}) {
    final isStart = isNotStarted(job);
    final isActive = job.tripStatus == 'in_progress';

    // Another trip is running: this one starts when that one is completed
    // (the Complete dialog offers to start it), so no separate start here.
    if (isStart && blockedBy != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_rounded, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Flexible(
              child: Text('Up next · starts when you complete the current trip',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
            ),
          ],
        ),
      );
    }

    if (isActive) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () =>
              context.push('/driver/active_job/${job.id}'),
          icon: const Icon(Icons.directions_car_rounded, size: 16),
          label: const Text('Continue Active Job'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      );
    } else if (isStart) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => startTrip(context, ref, job),
          icon: const Icon(Icons.play_arrow_rounded, size: 16),
          label: const Text('Start Trip'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A1942),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF4A1942).withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.today_rounded,
              size: 56,
              color: const Color(0xFF4A1942).withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'All Clear Today!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no trips scheduled for today. Enjoy your day!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildError(WidgetRef ref, Object err) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              isOfflineError(err)
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              size: 52,
              color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            friendlyErrorTitle(err),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 8),
          Text(friendlyErrorMessage(err),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(driverJobsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A1942),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'assigned':
        return {'label': 'Assigned', 'color': const Color(0xFF2196F3)};
      case 'in_progress':
        return {'label': 'In Progress', 'color': const Color(0xFF4CAF50)};
      case 'completed':
        return {'label': 'Completed', 'color': const Color(0xFF9E9E9E)};
      case 'inspection_pending':
        return {'label': 'Inspection', 'color': const Color(0xFFFF9800)};
      case 'accident':
        return {'label': 'Accident', 'color': const Color(0xFFF44336)};
      default:
        return {'label': 'Unassigned', 'color': const Color(0xFF9C27B0)};
    }
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : local.hour == 0
            ? 12
            : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${local.day} ${months[local.month - 1]}, $hour:$minute $period';
  }
}
