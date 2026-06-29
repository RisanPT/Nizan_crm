import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/fleet_service.dart';
import '../../../models/fleet_models.dart';
import 'package:url_launcher/url_launcher.dart';

class FleetAccidentsScreen extends ConsumerWidget {
  const FleetAccidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accidentsAsync = ref.watch(managerAccidentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: accidentsAsync.when(
        data: (accidents) {
          if (accidents.isEmpty) {
            return const Center(
              child: Text('No accident claims reported.', style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: accidents.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final accident = accidents[index];
              return _buildAccidentCard(context, accident);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildAccidentCard(BuildContext context, AccidentReport accident) {
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
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text('Accident Claim',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  accident.status.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(accident.description,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          if (accident.photos.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: accident.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(accident.photos[index], width: 80, height: 80, fit: BoxFit.cover),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final url = 'https://www.google.com/maps/search/?api=1&query=${accident.location.lat},${accident.location.lng}';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
            },
            icon: const Icon(Icons.location_on_outlined, size: 16),
            label: const Text('View Location on Map'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          )
        ],
      ),
    );
  }
}
