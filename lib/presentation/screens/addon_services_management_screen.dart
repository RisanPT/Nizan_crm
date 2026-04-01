import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/addon_service.dart';
import '../../core/models/list_page_params.dart';
import '../../core/theme/crm_theme.dart';
import '../common_widgets/paginated_footer.dart';
import '../../services/addon_service_service.dart';

class AddonServicesManagementScreen extends HookConsumerWidget {
  const AddonServicesManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final pageState = useState(1);
    const pageSize = 20;
    final asyncAddonServices = ref.watch(
      paginatedAddonServicesProvider(
        ListPageParams(page: pageState.value, limit: pageSize),
      ),
    );

    Future<void> handleBack() async {
      final didPop = await Navigator.of(context).maybePop();
      if (!didPop && context.mounted) {
        context.go('/services');
      }
    }

    Future<void> openEditor([AddonService? addonService]) async {
      final nameCtrl = TextEditingController(text: addonService?.name ?? '');
      final priceCtrl = TextEditingController(
        text: addonService == null ? '' : addonService.price.toStringAsFixed(0),
      );
      final descriptionCtrl = TextEditingController(
        text: addonService?.description ?? '',
      );
      var status = addonService?.status ?? 'active';

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(
                addonService == null
                    ? 'Add Add-on Service'
                    : 'Edit Add-on Service',
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Service'),
                    ),
                    12.h,
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                    12.h,
                    TextField(
                      controller: descriptionCtrl,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    12.h,
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
                        setState(() => status = value ?? status);
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
                        .read(addonServiceServiceProvider)
                        .saveAddonService(
                          id: addonService?.id,
                          name: nameCtrl.text.trim(),
                          price: double.tryParse(priceCtrl.text.trim()) ?? 0,
                          description: descriptionCtrl.text.trim(),
                          status: status,
                        );
                    ref.invalidate(addonServicesProvider);
                    ref.invalidate(paginatedAddonServicesProvider);
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    'Add-on Services',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Manage small-price add-on services used inside booking add-ons.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => openEditor(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Add-on'),
            ),
          ],
        ),
        24.h,
        Expanded(
          child: asyncAddonServices.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Failed to load add-on services: $error',
                style: TextStyle(color: crmColors.textSecondary),
              ),
            ),
            data: (response) {
              final addonServices = response.items;
              if (addonServices.isEmpty) {
                return Center(
                  child: Text(
                    'No add-on services yet.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                );
              }

              return ListView.separated(
                itemCount: addonServices.length,
                separatorBuilder: (context, index) => 16.h,
                itemBuilder: (context, index) {
                  final item = addonServices[index];
                  return Card(
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        item.description.isEmpty
                            ? 'No description'
                            : item.description,
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '₹ ${item.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: crmColors.success,
                            ),
                          ),
                          TextButton(
                            onPressed: () => openEditor(item),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(addonServiceServiceProvider)
                                  .deleteAddonService(item.id);
                              ref.invalidate(addonServicesProvider);
                              ref.invalidate(paginatedAddonServicesProvider);
                            },
                            child: Text(
                              'Delete',
                              style: TextStyle(color: crmColors.destructive),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        20.h,
        asyncAddonServices.maybeWhen(
          data: (response) => PaginatedFooter(
            page: response.page,
            limit: response.limit,
            totalPages: response.totalPages,
            totalItems: response.totalItems,
            currentItemCount: response.items.length,
            onPrevious: response.page > 1
                ? () => pageState.value -= 1
                : null,
            onNext: response.page < response.totalPages
                ? () => pageState.value += 1
                : null,
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
