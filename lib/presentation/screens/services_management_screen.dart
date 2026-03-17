import 'package:flutter/material.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class ServicesManagementScreen extends StatelessWidget {
  const ServicesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    // Placeholder data
    final services = [
      {
        'category': 'Hair Styling',
        'title': 'Balayage & Cut',
        'duration': '120 min',
        'price': '\$150.00',
        'image': 'https://picsum.photos/seed/salon/400/250',
      },
      {
        'category': 'Makeup & Bridal',
        'title': 'Bridal Trial Makeup',
        'duration': '90 min',
        'price': '\$90.00',
        'image': 'https://picsum.photos/seed/makeup/400/250',
      },
      {
        'category': 'Spa & Massage',
        'title': 'Deep Tissue Massage',
        'duration': '60 min',
        'price': '\$110.00',
        'image': 'https://picsum.photos/seed/massage/400/250',
      },
      {
        'category': 'Spa & Massage',
        'title': 'Hydrating Facial',
        'duration': '45 min',
        'price': '\$85.00',
        'image': 'https://picsum.photos/seed/facial/400/250',
      },
      {
        'category': 'Makeup & Bridal',
        'title': 'Evening Glam Makeup',
        'duration': '60 min',
        'price': '\$75.00',
        'image': 'https://picsum.photos/seed/glam/400/250',
      },
      {
        'category': 'Hair Styling',
        'title': "Men's Executive Grooming",
        'duration': '45 min',
        'price': '\$65.00',
        'image': 'https://picsum.photos/seed/grooming/400/250',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Services Management', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Manage your salon and beauty services, pricing, and durations.', style: TextStyle(color: crmColors.textSecondary)),
                ],
              ),
            ),
            if (!isMobile) ...[
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.filter_list, size: 18), label: const Text('Filter')),
              16.w,
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Service'),
                style: ElevatedButton.styleFrom(backgroundColor: crmColors.primary, foregroundColor: Colors.white),
              )
            ]
          ],
        ),
        if (isMobile) ...[
          16.h,
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.filter_list, size: 18), label: const Text('Filter'))),
              16.w,
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Service'),
                  style: ElevatedButton.styleFrom(backgroundColor: crmColors.primary, foregroundColor: Colors.white),
                ),
              )
            ],
          ),
        ],
        24.h,
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 1 : 3,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 1.1,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return _buildServiceCard(context, service);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(BuildContext context, Map<String, String> service) {
    final crmColors = context.crmColors;
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(service['image']!, fit: BoxFit.cover),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(4)),
                    child: Text(service['category']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(service['title']!, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: crmColors.textSecondary),
                          4.w,
                          Text(service['duration']!, style: TextStyle(fontSize: 13, color: crmColors.textSecondary)),
                        ],
                      ),
                      Text(service['price']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const Divider(height: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(foregroundColor: crmColors.textPrimary),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red.shade300),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
