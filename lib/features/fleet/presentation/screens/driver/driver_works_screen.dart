import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nizan_crm/features/fleet/services/fleet_service.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';

class DriverWorksScreen extends ConsumerStatefulWidget {
  const DriverWorksScreen({super.key});

  @override
  ConsumerState<DriverWorksScreen> createState() => _DriverWorksScreenState();
}

class _DriverWorksScreenState extends ConsumerState<DriverWorksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(driverJobsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: jobsAsync.when(
              data: (allJobs) {
                final upcomingJobs =
                    allJobs.where((j) => j.tripStatus != 'completed').toList();
                final completedJobs =
                    allJobs.where((j) => j.tripStatus == 'completed').toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildJobList(upcomingJobs, isCompleted: false),
                    _buildJobList(completedJobs, isCompleted: true),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF4A1942)),
              ),
              error: (err, stack) => _buildError(err.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3A0F35), Color(0xFF6B1A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Works',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Track all your assignments',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => ref.invalidate(driverJobsProvider),
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white70, size: 22),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Completed'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobList(List<FleetJob> jobs, {required bool isCompleted}) {
    if (jobs.isEmpty) {
      return _buildEmptyState(isCompleted);
    }

    return RefreshIndicator(
      color: const Color(0xFF4A1942),
      onRefresh: () async => ref.invalidate(driverJobsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          return _buildJobCard(jobs[index], isCompleted: isCompleted);
        },
      ),
    );
  }

  Widget _buildJobCard(FleetJob job, {required bool isCompleted}) {
    final statusInfo = _getStatusInfo(job.tripStatus);
    final now = DateTime.now();
    final start = job.serviceStart.toLocal();
    final isToday = start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    final isTomorrow = start.year == now.year &&
        start.month == now.month &&
        start.day == now.day + 1;

    String dayLabel = '';
    if (isToday) {
      dayLabel = 'Today';
    } else if (isTomorrow) {
      dayLabel = 'Tomorrow';
    }

    final hasMapUrl = job.mapUrl != null && job.mapUrl!.trim().isNotEmpty;
    final hasPoc = job.pocName != null && job.pocName!.trim().isNotEmpty;
    final hasEventSlot = job.eventSlot != null && job.eventSlot!.trim().isNotEmpty;
    final hasKm = job.travelDistanceKm > 0;

    // Get lead artist name from assignedStaff
    final leadArtists = job.assignedStaff
        .where((s) => s['roleType'] == 'lead' || s['roleType'] == 'assistant')
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: customer name + status ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A1942).withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 20,
                    color: Color(0xFF4A1942),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.customerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        '#${job.bookingNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(statusInfo),
              ],
            ),
          ),

          // ─── Divider ───────────────────────────────────────────────────
          const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F0F0)),

          // ─── Details grid ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                // Row 1: Service + Time
                Row(
                  children: [
                    _buildChip(
                      Icons.design_services_outlined,
                      job.service,
                      const Color(0xFF6C63FF),
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      Icons.access_time_rounded,
                      '${_formatTime(job.serviceStart)}${dayLabel.isNotEmpty ? ' · $dayLabel' : ' · ${_formatDate(job.serviceStart)}'}',
                      const Color(0xFF2196F3),
                    ),
                  ],
                ),

                // Row 2: Event Slot + Distance (if available)
                if (hasEventSlot || hasKm) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (hasEventSlot)
                        Expanded(
                          child: _buildChipRaw(
                            Icons.event_available_outlined,
                            job.eventSlot!,
                            const Color(0xFF009688),
                          ),
                        ),
                      if (hasEventSlot && hasKm) const SizedBox(width: 8),
                      if (hasKm)
                        Expanded(
                          child: _buildChipRaw(
                            Icons.social_distance_outlined,
                            '${job.travelDistanceKm.toStringAsFixed(1)} km',
                            const Color(0xFFFF5722),
                          ),
                        ),
                    ],
                  ),
                ],

                // Row 3: Address + Maps link
                if (job.address != null && job.address!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: hasMapUrl ? () => _openUrl(job.mapUrl!) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: hasMapUrl
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                            : Colors.grey.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: hasMapUrl
                            ? Border.all(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasMapUrl ? Icons.map_rounded : Icons.location_on_outlined,
                            size: 16,
                            color: hasMapUrl
                                ? const Color(0xFF4CAF50)
                                : Colors.grey[500],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              job.address!,
                              style: TextStyle(
                                fontSize: 12,
                                color: hasMapUrl
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasMapUrl) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.open_in_new_rounded, size: 11, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'Maps',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                // Row 4: Artists on this booking
                if (leadArtists.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.groups_outlined,
                            size: 15, color: Color(0xFF7B1FA2)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            leadArtists
                                .map((s) => s['artistName'] as String? ?? '')
                                .where((n) => n.isNotEmpty)
                                .join(', '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6A1B9A),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Text(
                          'Artists',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9C27B0),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],

                // Row 5: POC name + call button
                if (hasPoc) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: (job.pocPhone != null && job.pocPhone!.isNotEmpty)
                        ? () => _callPhone(job.pocPhone!)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.contact_phone_outlined,
                              size: 15, color: Color(0xFF1565C0)),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'POC',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF1976D2),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5),
                              ),
                              Text(
                                job.pocName!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF0D47A1),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (job.pocPhone != null && job.pocPhone!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.call_rounded,
                                      size: 13, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Call',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ─── Action button ─────────────────────────────────────────────
          if (!isCompleted) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _buildActionButton(job),
            ),
          ] else ...[
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> statusInfo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (statusInfo['color'] as Color).withValues(alpha: 0.12),
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
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String text, Color color) {
    return Expanded(
      child: _buildChipRaw(icon, text, color),
    );
  }

  Widget _buildChipRaw(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
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

  Widget _buildActionButton(FleetJob job) {
    final isStart =
        job.tripStatus == 'unassigned' || job.tripStatus == 'assigned';
    final isActive = job.tripStatus == 'in_progress';

    if (isStart) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _handleJobAction(job),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Start Trip'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A1942),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      );
    } else if (isActive) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _handleJobAction(job),
          icon: const Icon(Icons.directions_car_rounded, size: 18),
          label: const Text('View Active Job'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState(bool isCompleted) {
    return Center(
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
              isCompleted
                  ? Icons.check_circle_outline_rounded
                  : Icons.event_busy_rounded,
              size: 52,
              color: const Color(0xFF4A1942).withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isCompleted ? 'No completed works yet' : 'No upcoming works',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCompleted
                ? 'Completed jobs will appear here'
                : 'Check back later for new assignments',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 52, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Failed to load works',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 8),
            Text(err,
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
        return {'label': 'Inspect First', 'color': const Color(0xFFFF9800)};
      case 'accident':
        return {'label': 'Accident', 'color': const Color(0xFFF44336)};
      default:
        return {'label': 'Unassigned', 'color': const Color(0xFF9E9E9E)};
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour;
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${local.day} ${months[local.month - 1]}';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _handleJobAction(FleetJob job) {
    if (job.tripStatus == 'unassigned' || job.tripStatus == 'assigned') {
      context.push('/driver/inspection/${job.id}');
    } else {
      context.push('/driver/active_job/${job.id}');
    }
  }
}
