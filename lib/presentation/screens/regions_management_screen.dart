import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/service_region.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/region_service.dart';

class RegionsManagementScreen extends HookConsumerWidget {
  const RegionsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncRegions = ref.watch(regionsProvider);

    Future<void> handleBack() async {
      final didPop = await Navigator.of(context).maybePop();
      if (!didPop && context.mounted) {
        context.go('/services');
      }
    }

    Future<void> openRegionDialog([ServiceRegion? region]) async {
      final nameCtrl = TextEditingController(text: region?.name ?? '');
      var status = region?.status ?? 'active';

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(region == null ? 'Add Region' : 'Edit Region'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Region Name',
                      ),
                    ),
                    16.h,
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Inactive'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => status = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(regionServiceProvider)
                        .saveRegion(
                          id: region?.id,
                          name: nameCtrl.text.trim(),
                          status: status,
                        );
                    ref.invalidate(regionsProvider);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: handleBack,
              icon: const Icon(Icons.arrow_back),
            ),
            8.w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Regions',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Manage active and inactive regions used for package pricing.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (!isMobile)
              ElevatedButton.icon(
                onPressed: () => openRegionDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Region'),
              ),
          ],
        ),
        if (isMobile) ...[
          16.h,
          ElevatedButton.icon(
            onPressed: () => openRegionDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Region'),
          ),
        ],
        24.h,
        Expanded(
          child: asyncRegions.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Failed to load regions: $error',
                style: TextStyle(color: crmColors.textSecondary),
              ),
            ),
            data: (regions) {
              if (regions.isEmpty) {
                return Center(
                  child: Text(
                    'No regions found.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                );
              }

              return Card(
                child: ListView.separated(
                  itemCount: regions.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: crmColors.border),
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    final isActive = region.status == 'active';
                    return ListTile(
                      title: Text(
                        region.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: isActive
                              ? crmColors.success
                              : crmColors.textSecondary,
                        ),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => openRegionDialog(region),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(regionServiceProvider)
                                  .deleteRegion(region.id);
                              ref.invalidate(regionsProvider);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: crmColors.destructive,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
