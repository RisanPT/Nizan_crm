import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/models/employee.dart';
import '../../../core/models/vehicle.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../services/employee_service.dart';
import '../../../services/fleet_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../models/fleet_models.dart';
import '../../common_widgets/export_report_dialog.dart';
import 'fleet_mobile_ui.dart';
import 'package:intl/intl.dart';

String _extractId(dynamic obj) {
  if (obj is String) return obj;
  if (obj is Map && obj.containsKey('_id')) return obj['_id'].toString();
  if (obj is Map && obj.containsKey('id')) return obj['id'].toString();
  return '';
}

class FleetCompletedWorksScreen extends ConsumerWidget {
  const FleetCompletedWorksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crmColors = context.crmColors;
    final worksAsync = ref.watch(managerCompletedWorksProvider);
    final reviews = ref.watch(managerReviewsProvider).value ?? const <DriverReview>[];
    final vehicles = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
    final employees = ref.watch(employeesProvider).value ?? const <Employee>[];

    String vehicleNameOf(dynamic obj) {
      if (obj is Map) {
        if (obj['name'] != null) return obj['name'].toString();
        if (obj['registrationNumber'] != null) {
          return obj['registrationNumber'].toString();
        }
      }
      if (obj is String && obj.isNotEmpty) {
        final v = vehicles.cast<Vehicle?>().firstWhere(
              (item) => item?.id == obj,
              orElse: () => null,
            );
        if (v != null) {
          return v.registrationNumber.isNotEmpty
              ? '${v.name} · ${v.registrationNumber}'
              : v.name;
        }
      }
      return '—';
    }

    String driverNameOf(dynamic obj) {
      if (obj is Map && obj['name'] != null) return obj['name'].toString();
      if (obj is String && obj.isNotEmpty) {
        final e = employees.cast<Employee?>().firstWhere(
              (item) => item?.id == obj,
              orElse: () => null,
            );
        if (e != null) return e.name;
      }
      return '—';
    }

    DriverReview? reviewFor(FleetJob job) {
      for (final r in reviews) {
        if (_extractId(r.job) == job.id) return r;
      }
      return null;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: worksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Failed to load completed works: $err',
            style: TextStyle(color: crmColors.textSecondary),
          ),
        ),
        data: (works) {
          final reviewed = works.where((j) => reviewFor(j) != null).length;
          final pending = works.length - reviewed;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FleetMobileHeader(
                title: 'Completed Works',
                trailing: works.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => ExportReportDialog<FleetJob>(
                              title: 'Completed Works',
                              items: works,
                              getVehicleName: (j) => vehicleNameOf(j.vehicleId),
                              getDriverName: (j) => driverNameOf(j.driverId),
                              headers: const [
                                'Booking Number',
                                'Service',
                                'Date',
                                'Customer',
                                'Vehicle',
                                'Driver',
                                'Status'
                              ],
                              buildRow: (j) => [
                                j.bookingNumber,
                                j.service,
                                DateFormat('yyyy-MM-dd').format(j.serviceStart),
                                j.customerName,
                                vehicleNameOf(j.vehicleId),
                                driverNameOf(j.driverId),
                                j.tripStatus,
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.download_outlined, size: 20),
                        tooltip: 'Export',
                        style: IconButton.styleFrom(
                          foregroundColor: crmColors.accent,
                          backgroundColor: crmColors.accent.withValues(alpha: 0.10),
                          minimumSize: const Size(40, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                stats: [
                  FleetStat(
                      value: '${works.length}',
                      label: 'Total',
                      color: crmColors.primary),
                  FleetStat(
                      value: '$reviewed',
                      label: 'Reviewed',
                      color: crmColors.success),
                  FleetStat(
                      value: '$pending',
                      label: 'No Review',
                      color: crmColors.textSecondary),
                ],
              ),
              16.h,
              Expanded(
                child: works.isEmpty
                    ? const FleetEmptyState(
                        icon: Icons.task_alt_rounded,
                        title: 'No completed works',
                        subtitle: 'Finished trips will be listed here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: works.length,
                        separatorBuilder: (_, _) => 12.h,
                        itemBuilder: (context, index) {
                          final job = works[index];
                          return _CompletedJobCard(
                            job: job,
                            review: reviewFor(job),
                            driver: driverNameOf(job.driverId),
                            vehicle: vehicleNameOf(job.vehicleId),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CompletedJobCard extends StatelessWidget {
  final FleetJob job;
  final DriverReview? review;
  final String driver;
  final String vehicle;

  const _CompletedJobCard({
    required this.job,
    required this.review,
    required this.driver,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final dateFormat = DateFormat('MMM d, yyyy');
    return Container(
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crmColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: crmColors.success),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.task_alt_rounded,
                            color: crmColors.success, size: 19),
                        8.w,
                        Expanded(
                          child: Text(
                            'Job #${job.bookingNumber}',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: crmColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          dateFormat.format(job.serviceStart),
                          style: TextStyle(
                              fontSize: 12, color: crmColors.textSecondary),
                        ),
                      ],
                    ),
                    10.h,
                    Text(
                      job.service,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: crmColors.textPrimary,
                      ),
                    ),
                    6.h,
                    _metaRow(crmColors, Icons.person_outline, job.customerName),
                    if (driver != '—') ...[
                      4.h,
                      _metaRow(crmColors, Icons.badge_outlined, 'Driver · $driver'),
                    ],
                    if (vehicle != '—') ...[
                      4.h,
                      _metaRow(crmColors, Icons.directions_car_outlined,
                          'Vehicle · $vehicle'),
                    ],
                    12.h,
                    if (review != null)
                      _reviewSection(context, review!)
                    else
                      Text(
                        'No review submitted by artist yet.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: crmColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(CrmTheme crmColors, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: crmColors.textSecondary),
        6.w,
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: crmColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _reviewSection(BuildContext context, DriverReview review) {
    final crmColors = context.crmColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crmColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crmColors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Artist Review',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: crmColors.textPrimary),
              ),
              8.w,
              ...List.generate(5, (index) {
                return Icon(
                  index < review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: crmColors.accent,
                  size: 16,
                );
              }),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            6.h,
            Text(
              '"${review.comment}"',
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: crmColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
