import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/fleet_service.dart';
import '../../../models/fleet_models.dart';
import '../../common_widgets/export_report_dialog.dart';
import 'package:intl/intl.dart';

class FleetCompletedWorksScreen extends ConsumerWidget {
  const FleetCompletedWorksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worksAsync = ref.watch(managerCompletedWorksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: worksAsync.when(
        data: (works) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Completed Works',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (works.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => ExportReportDialog<FleetJob>(
                              title: 'Completed Works',
                              items: works,
                              getVehicleName: (j) => _extractName(j.vehicleId),
                              getDriverName: (j) => _extractName(j.driverId),
                              headers: const ['Booking Number', 'Service', 'Date', 'Customer', 'Vehicle', 'Driver', 'Status'],
                              buildRow: (j) => [
                                j.bookingNumber,
                                j.service,
                                DateFormat('yyyy-MM-dd').format(j.serviceStart),
                                j.customerName,
                                _extractName(j.vehicleId),
                                _extractName(j.driverId),
                                j.tripStatus,
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Export'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: works.isEmpty
                    ? const Center(
                        child: Text('No completed works found.', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: works.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final job = works[index];
                          return _buildCompletedJobCard(context, job, ref);
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

  Widget _buildCompletedJobCard(BuildContext context, FleetJob job, WidgetRef ref) {
    // Attempt to find if there is a review for this job
    // To do this fully optimized, the backend should return the review attached to the job
    // But for now, we can cross-reference if we load managerReviewsProvider
    final reviewsAsync = ref.watch(managerReviewsProvider);
    
    DriverReview? review;
    if (reviewsAsync.hasValue) {
      final reviews = reviewsAsync.value!;
      try {
        review = reviews.firstWhere((r) => _extractId(r.job) == job.id);
      } catch (_) {}
    }

    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.task_alt_rounded, color: Color(0xFF2E7D32), size: 20),
                  const SizedBox(width: 8),
                  Text('Job #${job.bookingNumber}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                ],
              ),
              Text(dateFormat.format(job.serviceStart),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 12),
          Text(job.service, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Customer: ${job.customerName}', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          
          if (job.driverId != null) ...[
             const SizedBox(height: 4),
             Text('Driver: ${_extractName(job.driverId)}', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          ],
          if (job.vehicleId != null) ...[
             const SizedBox(height: 4),
             Text('Vehicle: ${_extractName(job.vehicleId)}', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          
          if (review != null)
            _buildReviewSection(review)
          else
            const Text('No review submitted by artist yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildReviewSection(DriverReview review) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Artist Review: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ...List.generate(5, (index) {
                return Icon(
                  index < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber[700],
                  size: 16,
                );
              }),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('"${review.comment}"', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  String _extractId(dynamic obj) {
    if (obj is String) return obj;
    if (obj is Map && obj.containsKey('_id')) return obj['_id'].toString();
    if (obj is Map && obj.containsKey('id')) return obj['id'].toString();
    return '';
  }

  String _extractName(dynamic obj) {
    if (obj is String) return 'ID: $obj';
    if (obj is Map) {
      if (obj.containsKey('name')) return obj['name'].toString();
      if (obj.containsKey('registrationNumber')) return obj['registrationNumber'].toString();
    }
    return 'Unknown';
  }
}
