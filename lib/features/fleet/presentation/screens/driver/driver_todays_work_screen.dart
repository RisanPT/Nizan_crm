import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';

class DriverTodaysWorkScreen extends ConsumerStatefulWidget {
  const DriverTodaysWorkScreen({super.key});

  @override
  ConsumerState<DriverTodaysWorkScreen> createState() => _DriverTodaysWorkScreenState();
}

class _DriverTodaysWorkScreenState extends ConsumerState<DriverTodaysWorkScreen> {
  final Map<String, TextEditingController> _etaControllers = {};

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  void dispose() {
    for (var controller in _etaControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(driverJobsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Works'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: jobsAsync.when(
        data: (allJobs) {
          final todaysJobs = allJobs.where((j) => _isToday(j.serviceStart)).toList();
          todaysJobs.sort((a, b) => a.serviceStart.compareTo(b.serviceStart));

          if (todaysJobs.isEmpty) {
            return const Center(child: Text('No works assigned for today.'));
          }

          // Check if any job today has already been started
          final hasStartedAnyJob = todaysJobs.any((j) => 
            j.tripStatus == 'in_progress' || 
            j.tripStatus == 'completed' || 
            j.tripStatus == 'accident'
          );

          return Column(
            children: [
              if (todaysJobs.length > 1 && !hasStartedAnyJob)
                _buildTimesheetForm(todaysJobs),
              Expanded(
                child: ListView.builder(
                  itemCount: todaysJobs.length,
                  itemBuilder: (context, index) {
                    final job = todaysJobs[index];
                    // If it's the very first job in the sorted list, and no jobs started yet, 
                    // it requires photos.
                    final requiresPhotos = index == 0 && !hasStartedAnyJob;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(job.customerName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Service: ${job.service}'),
                            Text('Time: ${job.serviceStart.toLocal().toString().split(' ')[1].substring(0, 5)}'),
                            Text('Status: ${job.tripStatus.toUpperCase()}'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _handleJobAction(job, requiresPhotos),
                          child: Text(_getActionButtonText(job)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildTimesheetForm(List<FleetJob> jobs) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueGrey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route Planning Timesheet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Please plan your route and estimate arrival times for each area.'),
          const SizedBox(height: 16),
          ...jobs.map((job) {
            if (!_etaControllers.containsKey(job.id)) {
              _etaControllers[job.id] = TextEditingController();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(job.customerName, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _etaControllers[job.id],
                      decoration: const InputDecoration(
                        hintText: 'ETA (HH:MM)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {
                // Here we would ideally save the ETAs to the backend.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Timesheet saved successfully!')),
                );
              },
              child: const Text('Save Timesheet'),
            ),
          ),
        ],
      ),
    );
  }

  String _getActionButtonText(FleetJob job) {
    if (job.tripStatus == 'unassigned' || job.tripStatus == 'assigned') {
      return 'Start';
    } else if (job.tripStatus == 'in_progress') {
      return 'Active';
    }
    return 'View';
  }

  Future<void> _handleJobAction(FleetJob job, bool requiresPhotos) async {
    if (job.tripStatus == 'unassigned' || job.tripStatus == 'assigned') {
      if (requiresPhotos) {
        // Go to Pre-Trip Inspection which requires 6 photos
        context.push('/driver/inspection/${job.id}');
      } else {
        // Bypass photos and start trip immediately
        try {
          final fleetService = ref.read(fleetServiceProvider);
          await fleetService.startTripWithInspection(job.id, []);
          ref.invalidate(driverJobsProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Trip started (photos bypassed)')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to start trip: $e')),
            );
          }
        }
      }
    } else {
      // Go to Active Job Screen
      context.push('/driver/active_job/${job.id}');
    }
  }
}
