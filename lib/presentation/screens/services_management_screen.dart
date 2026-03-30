import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/package_service.dart';

class ServicesManagementScreen extends ConsumerWidget {
  const ServicesManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncPackages = ref.watch(packagesProvider);

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
                  Text(
                    'Package Management',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Manage packages, base pricing, advances, and region overrides.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (!isMobile)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/services/addons'),
                    icon: const Icon(
                      Icons.playlist_add_circle_outlined,
                      size: 18,
                    ),
                    label: const Text('Add-ons'),
                  ),
                  16.w,
                  OutlinedButton.icon(
                    onPressed: () => context.go('/services/regions'),
                    icon: const Icon(Icons.location_on_outlined, size: 18),
                    label: const Text('Regions'),
                  ),
                  16.w,
                  ElevatedButton.icon(
                    onPressed: () => context.go('/services/add'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Package'),
                  ),
                ],
              ),
          ],
        ),
        if (isMobile) ...[
          16.h,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/services/addons'),
                  icon: const Icon(
                    Icons.playlist_add_circle_outlined,
                    size: 18,
                  ),
                  label: const Text('Add-ons'),
                ),
              ),
              16.w,
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/services/regions'),
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  label: const Text('Regions'),
                ),
              ),
              16.w,
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/services/add'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Package'),
                ),
              ),
            ],
          ),
        ],
        24.h,
        Expanded(
          child: asyncPackages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Failed to load packages: $error',
                style: TextStyle(color: crmColors.textSecondary),
              ),
            ),
            data: (packages) {
              if (packages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: crmColors.border,
                      ),
                      16.h,
                      Text(
                        'No packages yet.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      8.h,
                      Text(
                        'Create your first package with regional pricing overrides.',
                        style: TextStyle(color: crmColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: packages.length,
                separatorBuilder: (context, index) => 16.h,
                itemBuilder: (context, index) {
                  final package = packages[index];
                  return Card(
                    child: Padding(
                      padding: 20.p,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      package.name,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    6.h,
                                    Text(
                                      package.description.isEmpty
                                          ? 'No description added.'
                                          : package.description,
                                      style: TextStyle(
                                        color: crmColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    context.go('/services/add?id=${package.id}'),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Edit'),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  await ref
                                      .read(packageServiceProvider)
                                      .deletePackage(package.id);
                                  ref.invalidate(packagesProvider);
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                ),
                                label: const Text('Delete'),
                                style: TextButton.styleFrom(
                                  foregroundColor: crmColors.destructive,
                                ),
                              ),
                            ],
                          ),
                          16.h,
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _InfoChip(
                                label: 'Base Price',
                                value: '₹ ${package.price.toStringAsFixed(0)}',
                              ),
                              _InfoChip(
                                label: 'Advance',
                                value:
                                    '₹ ${package.advanceAmount.toStringAsFixed(0)} / day',
                              ),
                              _InfoChip(
                                label: 'Region Overrides',
                                value: '${package.regionPrices.length}',
                              ),
                            ],
                          ),
                          if (package.regionPrices.isNotEmpty) ...[
                            16.h,
                            Text(
                              'Regional Pricing',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            12.h,
                            ...package.regionPrices.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.regionName.isEmpty
                                          ? 'Region ${item.regionId}'
                                          : item.regionName,
                                    ),
                                    Text(
                                      '₹ ${item.price.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: crmColors.success,
                                        fontWeight: FontWeight.w700,
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
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: crmColors.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: crmColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          4.h,
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: crmColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
