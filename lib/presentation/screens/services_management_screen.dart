import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/list_page_params.dart';
import '../../core/models/zone.dart';
import '../../core/models/geographic_state.dart';
import '../../core/models/service_region.dart';
import '../../core/models/district.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../common_widgets/paginated_footer.dart';
import '../../services/package_service.dart';
import '../../services/zone_service.dart';
import '../../services/state_service.dart';
import '../../services/region_service.dart';
import '../../services/district_service.dart';

class ServicesManagementScreen extends HookConsumerWidget {
  const ServicesManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final pageState = useState(1);
    const pageSize = 20;
    final asyncPackages = ref.watch(
      paginatedPackagesProvider(
        ListPageParams(page: pageState.value, limit: pageSize),
      ),
    );

    final asyncZones = ref.watch(zonesProvider);
    final asyncStates = ref.watch(statesProvider);
    final asyncRegions = ref.watch(regionsProvider);
    final asyncDistricts = ref.watch(districtsProvider);

    final zones = asyncZones.value ?? const <ZoneModel>[];
    final states = asyncStates.value ?? const <GeographicState>[];
    final regions = asyncRegions.value ?? const <ServiceRegion>[];
    final districts = asyncDistricts.value ?? const <District>[];

    final mainSearchQuery = useState('');
    final mainSelectedZoneId = useState('');
    final mainSelectedStateId = useState('');
    final mainSelectedRegionId = useState('');
    final mainSelectedDistrictId = useState('');

    final mainAvailableStates = states.where((s) => s.zoneId == mainSelectedZoneId.value).toList();
    final mainAvailableRegions = regions.where((r) => r.stateId == mainSelectedStateId.value).toList();
    final mainAvailableDistricts = districts.where((d) => d.regionId == mainSelectedRegionId.value).toList();

    if (asyncZones.isLoading ||
        asyncStates.isLoading ||
        asyncRegions.isLoading ||
        asyncDistricts.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    String resolveGeographicPath(String districtId) {
      final district = districts.cast<District?>().firstWhere(
        (d) => d?.id == districtId,
        orElse: () => null,
      );
      if (district == null) return 'District $districtId';

      final region = regions.cast<ServiceRegion?>().firstWhere(
        (r) => r?.id == district.regionId,
        orElse: () => null,
      );
      if (region == null) return district.name;

      final state = states.cast<GeographicState?>().firstWhere(
        (s) => s?.id == region.stateId,
        orElse: () => null,
      );
      if (state == null) return '${region.name} › ${district.name}';

      final stateZone = zones.cast<ZoneModel?>().firstWhere(
        (z) => z?.id == state.zoneId,
        orElse: () => null,
      );
      if (stateZone == null) return '${state.name} › ${region.name} › ${district.name}';

      return '${stateZone.name} › ${state.name} › ${region.name} › ${district.name}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isMobile) ...[
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
                      'Manage packages, base pricing, advances, and district overrides.',
                      style: TextStyle(color: crmColors.textSecondary),
                    ),
                  ],
                ),
              ),
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
                    label: const Text('Geographics'),
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
          20.h,
        ],
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
                  label: const Text('Geographics'),
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
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: crmColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list, size: 18, color: crmColors.textSecondary),
                    8.w,
                    const Text(
                      'Search & Filter Packages by Geographic Pricing',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                12.h,
                Row(
                  children: [
                    // Search Box
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 18),
                          hintText: 'Search packages by name...',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) => mainSearchQuery.value = val,
                      ),
                    ),
                    if (mainSearchQuery.value.isNotEmpty ||
                        mainSelectedZoneId.value.isNotEmpty ||
                        mainSelectedStateId.value.isNotEmpty ||
                        mainSelectedRegionId.value.isNotEmpty ||
                        mainSelectedDistrictId.value.isNotEmpty) ...[
                      12.w,
                      TextButton.icon(
                        onPressed: () {
                          mainSearchQuery.value = '';
                          mainSelectedZoneId.value = '';
                          mainSelectedStateId.value = '';
                          mainSelectedRegionId.value = '';
                          mainSelectedDistrictId.value = '';
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear Filters'),
                      ),
                    ],
                  ],
                ),
                12.h,
                Row(
                  children: [
                    // Zone Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: mainSelectedZoneId.value.isEmpty ? null : mainSelectedZoneId.value,
                        decoration: const InputDecoration(labelText: 'Zone', isDense: true),
                        items: zones.map((z) => DropdownMenuItem(value: z.id, child: Text(z.name))).toList(),
                        onChanged: (val) {
                          mainSelectedZoneId.value = val ?? '';
                          mainSelectedStateId.value = '';
                          mainSelectedRegionId.value = '';
                          mainSelectedDistrictId.value = '';
                        },
                      ),
                    ),
                    12.w,
                    // State Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: mainSelectedStateId.value.isEmpty ? null : mainSelectedStateId.value,
                        decoration: const InputDecoration(labelText: 'State', isDense: true),
                        items: mainAvailableStates.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                        onChanged: mainSelectedZoneId.value.isEmpty ? null : (val) {
                          mainSelectedStateId.value = val ?? '';
                          mainSelectedRegionId.value = '';
                          mainSelectedDistrictId.value = '';
                        },
                      ),
                    ),
                    12.w,
                    // Region Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: mainSelectedRegionId.value.isEmpty ? null : mainSelectedRegionId.value,
                        decoration: const InputDecoration(labelText: 'Region', isDense: true),
                        items: mainAvailableRegions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                        onChanged: mainSelectedStateId.value.isEmpty ? null : (val) {
                          mainSelectedRegionId.value = val ?? '';
                          mainSelectedDistrictId.value = '';
                        },
                      ),
                    ),
                    12.w,
                    // District Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: mainSelectedDistrictId.value.isEmpty ? null : mainSelectedDistrictId.value,
                        decoration: const InputDecoration(labelText: 'District', isDense: true),
                        items: mainAvailableDistricts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                        onChanged: mainSelectedRegionId.value.isEmpty ? null : (val) {
                          mainSelectedDistrictId.value = val ?? '';
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        20.h,
        Expanded(
          child: asyncPackages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Failed to load packages: $error',
                style: TextStyle(color: crmColors.textSecondary),
              ),
            ),
            data: (response) {
              var packages = response.items;

              // Filter packages client side by name
              if (mainSearchQuery.value.isNotEmpty) {
                final query = mainSearchQuery.value.toLowerCase();
                packages = packages.where((p) => p.name.toLowerCase().contains(query)).toList();
              }

              // Filter packages client side by geographic dropdown selectors
              if (mainSelectedZoneId.value.isNotEmpty ||
                  mainSelectedStateId.value.isNotEmpty ||
                  mainSelectedRegionId.value.isNotEmpty ||
                  mainSelectedDistrictId.value.isNotEmpty) {
                packages = packages.where((package) {
                  return package.districtPrices.any((override) {
                    final d = districts.cast<District?>().firstWhere((d) => d?.id == override.districtId, orElse: () => null);
                    if (d == null) return false;

                    if (mainSelectedDistrictId.value.isNotEmpty && d.id != mainSelectedDistrictId.value) return false;

                    final r = regions.cast<ServiceRegion?>().firstWhere((r) => r?.id == d.regionId, orElse: () => null);
                    if (r == null) {
                      return mainSelectedRegionId.value.isEmpty && mainSelectedStateId.value.isEmpty && mainSelectedZoneId.value.isEmpty;
                    }
                    if (mainSelectedRegionId.value.isNotEmpty && r.id != mainSelectedRegionId.value) return false;

                    final s = states.cast<GeographicState?>().firstWhere((s) => s?.id == r.stateId, orElse: () => null);
                    if (s == null) {
                      return mainSelectedStateId.value.isEmpty && mainSelectedZoneId.value.isEmpty;
                    }
                    if (mainSelectedStateId.value.isNotEmpty && s.id != mainSelectedStateId.value) return false;

                    final z = zones.cast<ZoneModel?>().firstWhere((z) => z?.id == s.zoneId, orElse: () => null);
                    if (z == null) {
                      return mainSelectedZoneId.value.isEmpty;
                    }
                    if (mainSelectedZoneId.value.isNotEmpty && z.id != mainSelectedZoneId.value) return false;

                    return true;
                  });
                }).toList();
              }

              if (packages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_outlined,
                        size: 48,
                        color: crmColors.border,
                      ),
                      16.h,
                      Text(
                        'No packages found.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      8.h,
                      Text(
                        'Try adjusting your search query or filters.',
                        style: TextStyle(color: crmColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final int columns = width < 600 ? 1 : (width < 1100 ? 2 : 3);
                  final cardWidth = (width - (16 * (columns - 1))) / columns;

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: packages.map((package) {
                          return SizedBox(
                            width: cardWidth,
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: crmColors.border),
                              ),
                              child: InkWell(
                                onTap: () => context.go('/services/detail?id=${package.id}'),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              package.name,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18),
                                            onPressed: () => context.go('/services/add?id=${package.id}'),
                                            tooltip: 'Edit Package',
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, size: 18, color: crmColors.destructive),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Delete Package'),
                                                  content: Text('Are you sure you want to delete "${package.name}"?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.of(ctx).pop(false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => Navigator.of(ctx).pop(true),
                                                      child: Text('Delete', style: TextStyle(color: crmColors.destructive)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await ref.read(packageServiceProvider).deletePackage(package.id);
                                                ref.invalidate(packagesProvider);
                                                ref.invalidate(paginatedPackagesProvider);
                                              }
                                            },
                                            tooltip: 'Delete Package',
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                      8.h,
                                      Text(
                                        package.description.isEmpty
                                            ? 'No description added.'
                                            : package.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: crmColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      16.h,
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: crmColors.success.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'BASE PRICE',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: crmColors.success,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                  4.h,
                                                  Text(
                                                    '₹ ${package.price.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: crmColors.success,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          12.w,
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: crmColors.secondary,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'ADVANCE',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: crmColors.textSecondary,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                  4.h,
                                                  Text(
                                                    '₹ ${package.advanceAmount.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: crmColors.textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (package.districtPrices.isNotEmpty) ...[
                                        16.h,
                                        const Divider(),
                                        12.h,
                                        Row(
                                          children: [
                                            Icon(Icons.map_outlined, size: 16, color: crmColors.primary),
                                            8.w,
                                            Text(
                                              'Geographic Pricing Overrides',
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        8.h,
                                        Container(
                                          constraints: const BoxConstraints(maxHeight: 180),
                                          child: ListView.separated(
                                            shrinkWrap: true,
                                            physics: const ClampingScrollPhysics(),
                                            itemCount: package.districtPrices.length > 3 ? 3 : package.districtPrices.length,
                                            separatorBuilder: (context, index) => const Divider(height: 8),
                                            itemBuilder: (context, index) {
                                              final item = package.districtPrices[index];
                                              final geoPath = resolveGeographicPath(item.districtId);
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        geoPath,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                          color: crmColors.textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    8.w,
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: crmColors.primary.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        '₹ ${item.price.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          color: crmColors.primary,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        if (package.districtPrices.length > 3) ...[
                                          8.h,
                                          Text(
                                            '+ ${package.districtPrices.length - 3} more geographic overrides...',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: crmColors.primary,
                                            ),
                                          ),
                                        ],
                                      ],
                                      16.h,
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => context.go('/services/detail?id=${package.id}'),
                                          icon: const Icon(Icons.arrow_forward, size: 14),
                                          label: const Text('View & Manage Overrides'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        20.h,
        asyncPackages.maybeWhen(
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

