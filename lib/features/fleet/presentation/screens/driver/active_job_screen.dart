import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/fleet/services/fleet_service.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'accident_report_screen.dart';

class ActiveJobScreen extends ConsumerStatefulWidget {
  final String jobId;
  const ActiveJobScreen({super.key, required this.jobId});

  @override
  ConsumerState<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends ConsumerState<ActiveJobScreen> {
  bool _isCompleting = false;

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(driverJobsProvider);

    return jobsAsync.when(
      data: (jobs) {
        final job = jobs.cast<FleetJob?>().firstWhere(
              (j) => j?.id == widget.jobId,
              orElse: () => null,
            );

        if (job == null) {
          return _buildNotFound(context);
        }

        return _buildScreen(context, job);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4A1942))),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildScreen(BuildContext context, FleetJob job) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          _buildHeader(context, job),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatusCard(job),
                  const SizedBox(height: 14),
                  _buildJobDetailsCard(job),
                  const SizedBox(height: 14),
                  if (job.preTripPhotos.isNotEmpty)
                    _buildPhotosCard(job),
                  const SizedBox(height: 28),
                  _buildCompleteButton(context, job),
                  const SizedBox(height: 12),
                  _buildAddExpenseButton(context, job),
                  const SizedBox(height: 12),
                  _buildAccidentButton(context, job),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FleetJob job) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Active Job',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Text(job.customerName,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_car_rounded,
                        color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('In Progress',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(FleetJob job) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: Color(0xFF2E7D32), size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trip In Progress',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B5E20))),
                SizedBox(height: 3),
                Text('Drive safely. Complete the job when you arrive.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF388E3C))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobDetailsCard(FleetJob job) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Job Details',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.person_outline_rounded, 'Customer',
              job.customerName, const Color(0xFF4A1942)),
          _buildDetailRow(Icons.confirmation_number_outlined, 'Booking',
              '#${job.bookingNumber}', Colors.grey),
          _buildDetailRow(Icons.design_services_outlined, 'Service',
              job.service, const Color(0xFF6C63FF)),
          if (job.eventSlot != null && job.eventSlot!.isNotEmpty)
            _buildDetailRow(Icons.event_available_outlined, 'Slot',
                job.eventSlot!, const Color(0xFF009688)),
          if (job.address != null && job.address!.isNotEmpty)
            _buildDetailRow(Icons.location_on_outlined, 'Location',
                job.address!, const Color(0xFF4CAF50)),
          if (job.pocName != null && job.pocName!.isNotEmpty)
            _buildDetailRow(Icons.contact_phone_outlined, 'POC',
                '${job.pocName}${job.pocPhone != null ? " · ${job.pocPhone}" : ""}',
                const Color(0xFF2196F3)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard(FleetJob job) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: Color(0xFF4A1942), size: 16),
              const SizedBox(width: 6),
              Text('Pre-Trip Photos (${job.preTripPhotos.length})',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: job.preTripPhotos.length,
              itemBuilder: (_, i) => Container(
                width: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: NetworkImage(job.preTripPhotos[i]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton(BuildContext context, FleetJob job) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isCompleting ? null : () => _confirmComplete(context, job),
        icon: _isCompleting
            ? const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Icon(Icons.check_circle_outline_rounded, size: 22),
        label: Text(
          _isCompleting ? 'Completing...' : 'Complete Job',
          style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
      ),
    );
  }

  Widget _buildAddExpenseButton(BuildContext context, FleetJob job) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isCompleting ? null : () => context.push('/driver/works/${job.id}/expense'),
        icon: const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF1976D2)),
        label: const Text('Add Expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1976D2))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildAccidentButton(BuildContext context, FleetJob job) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isCompleting
            ? null
            : () => _openAccidentReport(context, job),
        icon: const Icon(Icons.warning_amber_rounded,
            size: 20, color: Color(0xFFB71C1C)),
        label: const Text('Report Accident',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB71C1C))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Job not found'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go('/driver/jobs'),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmComplete(BuildContext context, FleetJob job) async {
    final jobs = ref.read(driverJobsProvider).value ?? [];
    final now = DateTime.now();
    final remaining = jobs.where((j) {
      if (j.id == job.id) return false;
      if (j.serviceStart.year != now.year || j.serviceStart.month != now.month || j.serviceStart.day != now.day) return false;
      return ['unassigned', 'assigned', 'in_progress'].contains(j.tripStatus);
    }).length;
    
    final isLastJob = remaining == 0;
    String? parkedLocation;
    final locCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Complete Job?', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to mark this job as completed? This action cannot be undone.'),
            if (isLastJob) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text('This is your last job today!', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Where is the vehicle parked?', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: locCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g., Office Parking, Home, etc.',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (isLastJob && locCtrl.text.trim().isEmpty) {
                 ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter where you parked the vehicle.')));
                 return;
              }
              parkedLocation = locCtrl.text.trim();
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // ignore: use_build_context_synchronously  
    final messenger = ScaffoldMessenger.of(context);
    // ignore: use_build_context_synchronously
    final router = GoRouter.of(context);

    setState(() => _isCompleting = true);
    try {
      await ref.read(fleetServiceProvider).completeJob(jobId: job.id, parkedLocation: parkedLocation?.isNotEmpty == true ? parkedLocation : null);
      ref.invalidate(driverJobsProvider);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Job completed! Great work 🎉'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        router.go('/driver/works');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompleting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openAccidentReport(BuildContext context, FleetJob job) {
    final v = job.vehicleId;
    final vehicleId = v is Map
        ? (v['_id'] ?? '').toString()
        : (v ?? '').toString();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AccidentReportScreen(jobId: job.id, vehicleId: vehicleId),
      ),
    );
  }
}
