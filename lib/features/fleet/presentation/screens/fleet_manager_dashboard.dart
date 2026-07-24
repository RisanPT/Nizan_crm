import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/fleet/services/fleet_service.dart';

class FleetManagerDashboard extends ConsumerWidget {
  const FleetManagerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fleet Manager Dashboard'),
          backgroundColor: Colors.blueGrey[900],
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Driver Reviews'),
              Tab(text: 'Accident Reports'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DriverReviewsTab(),
            _AccidentsTab(),
          ],
        ),
      ),
    );
  }
}

class _DriverReviewsTab extends ConsumerWidget {
  const _DriverReviewsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(managerReviewsProvider);

    return reviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) return const Center(child: Text('No reviews found.'));
        return ListView.builder(
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('Driver ID: ${review.driver}'), // populate driver details if populated
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Artist ID: ${review.artist}'),
                    Row(
                      children: List.generate(5, (starIdx) {
                        return Icon(
                          starIdx < review.rating ? Icons.star : Icons.star_border,
                          size: 16,
                          color: Colors.amber,
                        );
                      }),
                    ),
                    if (review.comment != null && review.comment!.isNotEmpty)
                      Text('Comment: ${review.comment}'),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _AccidentsTab extends ConsumerWidget {
  const _AccidentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accidentsAsync = ref.watch(managerAccidentsProvider);

    return accidentsAsync.when(
      data: (accidents) {
        if (accidents.isEmpty) return const Center(child: Text('No accidents reported.'));
        return ListView.builder(
          itemCount: accidents.length,
          itemBuilder: (context, index) {
            final acc = accidents[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('Vehicle ID: ${acc.vehicle}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Driver ID: ${acc.driver}'),
                    Text('Location: Lat ${acc.location.lat}, Lng ${acc.location.lng}'),
                    Text('Status: ${acc.status.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(acc.description),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
