import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../models/fleet_models.dart';
import '../../../services/fleet_service.dart';
import 'fleet_mobile_ui.dart';

bool _isResolved(String status) {
  final s = status.toLowerCase();
  return s == 'resolved' || s == 'closed' || s == 'completed' || s == 'settled';
}

Color _accidentStatusColor(String status, CrmTheme colors) {
  final s = status.toLowerCase();
  if (_isResolved(status)) return colors.success;
  if (s == 'pending' ||
      s == 'in_review' ||
      s == 'in review' ||
      s == 'processing' ||
      s == 'reviewing') {
    return colors.warning;
  }
  return colors.destructive;
}

class FleetAccidentsScreen extends ConsumerWidget {
  const FleetAccidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crmColors = context.crmColors;
    final accidentsAsync = ref.watch(managerAccidentsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: accidentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Failed to load accidents: $err',
            style: TextStyle(color: crmColors.textSecondary),
          ),
        ),
        data: (accidents) {
          final open = accidents.where((a) => !_isResolved(a.status)).length;
          final resolved = accidents.where((a) => _isResolved(a.status)).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FleetMobileHeader(
                title: 'Accident Claims',
                stats: [
                  FleetStat(
                      value: '${accidents.length}',
                      label: 'Total',
                      color: crmColors.primary),
                  FleetStat(
                      value: '$open',
                      label: 'Open',
                      color: crmColors.destructive),
                  FleetStat(
                      value: '$resolved',
                      label: 'Resolved',
                      color: crmColors.success),
                ],
              ),
              16.h,
              Expanded(
                child: accidents.isEmpty
                    ? const FleetEmptyState(
                        icon: Icons.verified_user_outlined,
                        title: 'No accident claims',
                        subtitle: 'Reported accidents will show up here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: accidents.length,
                        separatorBuilder: (_, _) => 12.h,
                        itemBuilder: (context, index) {
                          final a = accidents[index];
                          return _AccidentCard(
                            accident: a,
                            vehicle:
                                a.vehicle.isEmpty ? 'Vehicle' : a.vehicle,
                            driver: a.driver.isEmpty ? 'Driver' : a.driver,
                            color: _accidentStatusColor(a.status, crmColors),
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

class _AccidentCard extends StatelessWidget {
  final AccidentReport accident;
  final String vehicle;
  final String driver;
  final Color color;

  const _AccidentCard({
    required this.accident,
    required this.vehicle,
    required this.driver,
    required this.color,
  });

  Future<void> _openMap(BuildContext context) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${accident.location.lat},${accident.location.lng}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the map link.')),
      );
    }
  }

  Widget _oppRow(
      BuildContext context, IconData icon, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: crm.textSecondary),
          6.w,
          Text('$label: ',
              style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          Expanded(
            child: Text(value.trim(),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: crm.textPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Container(
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            color: color.withValues(alpha: 0.06),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: color, size: 22),
                ),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accident Claim',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: crmColors.textPrimary,
                        ),
                      ),
                      2.h,
                      Text(
                        vehicle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: crmColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.30)),
                  ),
                  child: Text(
                    accident.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 15, color: crmColors.textSecondary),
                    6.w,
                    Expanded(
                      child: Text(
                        driver,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: crmColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if ((accident.location.address ?? '').trim().isNotEmpty) ...[
                  8.h,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place_outlined,
                          size: 15, color: crmColors.textSecondary),
                      6.w,
                      Expanded(
                        child: Text(
                          accident.location.address!.trim(),
                          style: TextStyle(
                              fontSize: 12.5, color: crmColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
                if (accident.description.trim().isNotEmpty) ...[
                  10.h,
                  Text(
                    accident.description,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: crmColors.textPrimary,
                    ),
                  ),
                ],
                if (accident.opposite?.hasData ?? false) ...[
                  12.h,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.groups_outlined, size: 15, color: color),
                            6.w,
                            Text('Other Party Involved',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: color)),
                          ],
                        ),
                        8.h,
                        _oppRow(context, Icons.person_outline, 'Name',
                            accident.opposite!.name),
                        _oppRow(context, Icons.call_outlined, 'Phone',
                            accident.opposite!.phone),
                        _oppRow(context, Icons.directions_car_outlined,
                            'Vehicle', accident.opposite!.vehicleNumber),
                        _oppRow(context, Icons.notes_outlined, 'Notes',
                            accident.opposite!.notes),
                      ],
                    ),
                  ),
                ],
                if (accident.photos.isNotEmpty) ...[
                  12.h,
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: accident.photos.length,
                      separatorBuilder: (_, _) => 8.w,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            accident.photos[index],
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 76,
                              height: 76,
                              color: crmColors.input,
                              child: Icon(Icons.broken_image_outlined,
                                  color: crmColors.textSecondary, size: 22),
                            ),
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                    ? child
                                    : Container(
                                        width: 76,
                                        height: 76,
                                        color: crmColors.input,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        ),
                                      ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                12.h,
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openMap(context),
                    icon: const Icon(Icons.location_on_outlined, size: 18),
                    label: const Text('View Location on Map'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: crmColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
