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
import '../../core/models/pincode.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../common_widgets/paginated_footer.dart';

import '../../services/zone_service.dart';
import '../../services/state_service.dart';
import '../../services/region_service.dart';
import '../../services/district_service.dart';
import '../../services/pincode_service.dart';

class GeographicManagementScreen extends HookConsumerWidget {
  const GeographicManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    final selectedCategory = useState<String?>(null);
    final selectedZone = useState<ZoneModel?>(null);
    final viewMode = useState<String>('grid');
    final searchQuery = useState<String>('');
    final searchCtrl = useTextEditingController();

    // Pagination states for all tabs
    final zonePage = useState(1);
    final statePage = useState(1);
    final regionPage = useState(1);
    final districtPage = useState(1);
    final pincodePage = useState(1);

    const pageSize = 20;

    // Riverpod Watches
    final asyncZones = ref.watch(
      paginatedZonesProvider(
        ListPageParams(page: zonePage.value, limit: pageSize),
      ),
    );
    final asyncStates = ref.watch(
      paginatedStatesProvider(
        ListPageParams(page: statePage.value, limit: pageSize),
      ),
    );
    final asyncRegions = ref.watch(
      paginatedRegionsProvider(
        ListPageParams(page: regionPage.value, limit: pageSize),
      ),
    );
    final asyncDistricts = ref.watch(
      paginatedDistrictsProvider(
        ListPageParams(page: districtPage.value, limit: pageSize),
      ),
    );
    final asyncPincodes = ref.watch(
      paginatedPincodesProvider(
        ListPageParams(page: pincodePage.value, limit: pageSize),
      ),
    );

    // Watch unpaginated providers so they are preloaded and updated in real-time
    final zonesVal = ref.watch(zonesProvider);
    final statesVal = ref.watch(statesProvider);
    final regionsVal = ref.watch(regionsProvider);
    final districtsVal = ref.watch(districtsProvider);
    final pincodesVal = ref.watch(pincodesProvider);

    Future<void> handleBack() async {
      final didPop = await Navigator.of(context).maybePop();
      if (!didPop && context.mounted) {
        context.go('/services');
      }
    }

    // Modal dialog trigger helpers
    Future<void> openZoneDialog([ZoneModel? zone]) async {
      final nameCtrl = TextEditingController(text: zone?.name ?? '');
      var status = zone?.status ?? 'active';

      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(zone == null ? 'Add Zone' : 'Edit Zone'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Zone Name'),
                  ),
                  16.h,
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (value) => setState(() => status = value!),
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
                      .read(zoneServiceProvider)
                      .saveZone(
                        id: zone?.id,
                        name: nameCtrl.text.trim(),
                        status: status,
                      );
                  ref.invalidate(zonesProvider);
                  ref.invalidate(paginatedZonesProvider);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> openStateDialog([GeographicState? state]) async {
      final nameCtrl = TextEditingController(text: state?.name ?? '');
      var status = state?.status ?? 'active';
      var selectedZoneId = state?.zoneId ?? '';

      // Get active zones for dropdown
      final activeZones = await ref.read(zonesProvider.future);

      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(state == null ? 'Add State' : 'Edit State'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'State Name'),
                  ),
                  16.h,
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedZoneId.isEmpty
                        ? null
                        : selectedZoneId,
                    items: activeZones
                        .map(
                          (z) => DropdownMenuItem(
                            value: z.id,
                            child: Text(z.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedZoneId = value!),
                    decoration: const InputDecoration(labelText: 'Select Zone'),
                  ),
                  16.h,
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (value) => setState(() => status = value!),
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
                  if (selectedZoneId.isEmpty) return;
                  await ref
                      .read(stateServiceProvider)
                      .saveState(
                        id: state?.id,
                        name: nameCtrl.text.trim(),
                        zoneId: selectedZoneId,
                        status: status,
                      );
                  ref.invalidate(statesProvider);
                  ref.invalidate(paginatedStatesProvider);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> openRegionDialog([ServiceRegion? region]) async {
      final nameCtrl = TextEditingController(text: region?.name ?? '');
      var status = region?.status ?? 'active';
      var selectedStateId = region?.stateId ?? '';

      // Get active states for dropdown
      final activeStates = await ref.read(statesProvider.future);

      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(region == null ? 'Add Region' : 'Edit Region'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Region Name'),
                  ),
                  16.h,
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedStateId.isEmpty ? null : selectedStateId,
                    items: activeStates
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedStateId = value!),
                    decoration: const InputDecoration(
                      labelText: 'Select State',
                    ),
                  ),
                  16.h,
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (value) => setState(() => status = value!),
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
                  if (selectedStateId.isEmpty) return;
                  await ref
                      .read(regionServiceProvider)
                      .saveRegion(
                        id: region?.id,
                        name: nameCtrl.text.trim(),
                        stateId: selectedStateId,
                        status: status,
                      );
                  ref.invalidate(regionsProvider);
                  ref.invalidate(paginatedRegionsProvider);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> openDistrictDialog([District? district]) async {
      final nameCtrl = TextEditingController(text: district?.name ?? '');
      var status = district?.status ?? 'active';
      var selectedRegionId = district?.regionId ?? '';

      // Get active regions for dropdown
      final activeRegions = await ref.read(regionsProvider.future);

      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(district == null ? 'Add District' : 'Edit District'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'District Name',
                    ),
                  ),
                  16.h,
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedRegionId.isEmpty ? null : selectedRegionId,
                    items: activeRegions
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(r.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedRegionId = value!),
                    decoration: const InputDecoration(
                      labelText: 'Select Region',
                    ),
                  ),
                  16.h,
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (value) => setState(() => status = value!),
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
                  if (selectedRegionId.isEmpty) return;
                  await ref
                      .read(districtServiceProvider)
                      .saveDistrict(
                        id: district?.id,
                        name: nameCtrl.text.trim(),
                        regionId: selectedRegionId,
                        status: status,
                      );
                  ref.invalidate(districtsProvider);
                  ref.invalidate(paginatedDistrictsProvider);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> openPincodeDialog([Pincode? pincode]) async {
      final codeCtrl = TextEditingController(text: pincode?.code ?? '');
      var status = pincode?.status ?? 'active';
      var selectedDistrictId = pincode?.districtId ?? '';

      // Get active districts for dropdown
      final activeDistricts = await ref.read(districtsProvider.future);

      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(pincode == null ? 'Add Pincode' : 'Edit Pincode'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pincode / Postal Code',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  16.h,
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedDistrictId.isEmpty
                        ? null
                        : selectedDistrictId,
                    items: activeDistricts
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(d.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedDistrictId = value!),
                    decoration: const InputDecoration(
                      labelText: 'Select District',
                    ),
                  ),
                  16.h,
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (value) => setState(() => status = value!),
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
                  if (selectedDistrictId.isEmpty) return;
                  await ref
                      .read(pincodeServiceProvider)
                      .savePincode(
                        id: pincode?.id,
                        code: codeCtrl.text.trim(),
                        districtId: selectedDistrictId,
                        status: status,
                      );
                  ref.invalidate(pincodesProvider);
                  ref.invalidate(paginatedPincodesProvider);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    }

    if (selectedCategory.value == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = isMobile ? 1 : (constraints.maxWidth > 900 ? 3 : 2);
          final categories = [
            {
              'id': 'Zones',
              'title': 'Zones',
              'description': 'Highest level region groups (e.g. North Zone, South Zone).',
              'icon': Icons.public_outlined,
              'count': zonesVal.value?.length ?? 0,
              'activeCount': zonesVal.value?.where((z) => z.isActive).length ?? 0,
              'color': Colors.blue,
            },
            {
              'id': 'States',
              'title': 'States',
              'description': 'States within each zone (e.g. Kerala, Tamil Nadu).',
              'icon': Icons.map_outlined,
              'count': statesVal.value?.length ?? 0,
              'activeCount': statesVal.value?.where((s) => s.isActive).length ?? 0,
              'color': Colors.indigo,
            },
            {
              'id': 'Regions',
              'title': 'Regions',
              'description': 'Regional hubs or clusters inside states.',
              'icon': Icons.location_city_outlined,
              'count': regionsVal.value?.length ?? 0,
              'activeCount': regionsVal.value?.where((r) => r.isActive).length ?? 0,
              'color': Colors.teal,
            },
            {
              'id': 'Districts',
              'title': 'Districts',
              'description': 'Administrative districts or counties.',
              'icon': Icons.explore_outlined,
              'count': districtsVal.value?.length ?? 0,
              'activeCount': districtsVal.value?.where((d) => d.isActive).length ?? 0,
              'color': Colors.orange,
            },
            {
              'id': 'Pincodes',
              'title': 'Pincodes',
              'description': 'Postal codes for localized operations.',
              'icon': Icons.pin_drop_outlined,
              'count': pincodesVal.value?.length ?? 0,
              'activeCount': pincodesVal.value?.where((p) => p.isActive).length ?? 0,
              'color': Colors.red,
            },
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
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
                            'Geographic Configuration',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Select a level in the geographic hierarchy to configure data.',
                            style: TextStyle(color: crmColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isMobile ? 2.0 : 1.6,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return _buildCategoryCard(
                      context: context,
                      title: cat['title'] as String,
                      description: cat['description'] as String,
                      icon: cat['icon'] as IconData,
                      count: cat['count'] as int,
                      activeCount: cat['activeCount'] as int,
                      color: cat['color'] as Color,
                      onTap: () => selectedCategory.value = cat['id'] as String,
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    }

    final category = selectedCategory.value!;

    Widget buildInnerHeader({
      required String title,
      required IconData icon,
      required VoidCallback onAdd,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                selectedCategory.value = null;
                selectedZone.value = null;
                searchQuery.value = '';
                searchCtrl.clear();
              },
              icon: const Icon(Icons.arrow_back),
            ),
            8.w,
            Icon(icon, size: 28, color: theme.colorScheme.primary),
            12.w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    category == 'Zones'
                        ? 'Manage, add, and search geographic $category.'
                        : 'Search and view geographic $category.',
                    style: TextStyle(color: crmColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(viewMode.value == 'grid' ? Icons.list_alt_rounded : Icons.grid_view_rounded),
              onPressed: () {
                viewMode.value = viewMode.value == 'grid' ? 'table' : 'grid';
              },
              tooltip: viewMode.value == 'grid' ? 'Switch to Table View' : 'Switch to Grid View',
            ),
            if (category == 'Zones') ...[
              8.w,
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add $category'),
              ),
            ],
          ],
        ),
      );
    }

    Widget buildSearchFilterBar() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: searchCtrl,
            onChanged: (val) => searchQuery.value = val,
            decoration: InputDecoration(
              hintText: 'Search $category by name or code...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.value.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchCtrl.clear();
                        searchQuery.value = '';
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      );
    }

    Widget buildBody() {
      switch (category) {
        case 'Zones':
          if (selectedZone.value != null) {
            final zone = selectedZone.value!;
            // Filter states matching zoneId
            final zoneStates = statesVal.value?.where((s) => s.zoneId == zone.id).toList() ?? [];
            final stateIds = zoneStates.map((s) => s.id).toSet();
            // Filter regions matching stateIds
            final zoneRegions = regionsVal.value?.where((r) => stateIds.contains(r.stateId)).toList() ?? [];
            final regionIds = zoneRegions.map((r) => r.id).toSet();
            // Filter districts matching regionIds
            final zoneDistricts = districtsVal.value?.where((d) => regionIds.contains(d.regionId)).toList() ?? [];
            final districtIds = zoneDistricts.map((d) => d.id).toSet();
            // Filter pincodes matching districtIds
            final zonePincodes = pincodesVal.value?.where((p) => districtIds.contains(p.districtId)).toList() ?? [];

            return _buildZoneDetailsView(
              context: context,
              zone: zone,
              states: zoneStates,
              regions: zoneRegions,
              districts: zoneDistricts,
              pincodes: zonePincodes,
              onBack: () => selectedZone.value = null,
              crmColors: crmColors,
              theme: theme,
              isMobile: isMobile,
            );
          }
          return asyncZones.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading zones: $err')),
            data: (res) {
              final filteredItems = searchQuery.value.isEmpty
                  ? res.items
                  : res.items.where((z) => z.name.toLowerCase().contains(searchQuery.value.toLowerCase())).toList();
              return _buildGeographicContent<ZoneModel>(
                items: filteredItems,
                viewMode: viewMode.value,
                isMobile: isMobile,
                crmColors: crmColors,
                gridItemBuilder: (z) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
                  ),
                  child: InkWell(
                    onTap: () => selectedZone.value = z,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_tree_outlined, size: 18, color: Colors.grey),
                                    8.w,
                                    Expanded(
                                      child: Text(
                                        z.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusChip(z.isActive, crmColors),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => openZoneDialog(z),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                              16.w,
                              IconButton(
                                icon: Icon(Icons.delete, size: 18, color: crmColors.destructive),
                                onPressed: () async {
                                  await ref.read(zoneServiceProvider).deleteZone(z.id);
                                  ref.invalidate(zonesProvider);
                                  ref.invalidate(paginatedZonesProvider);
                                },
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                headerRow: const ['Name', 'Status', 'Actions'],
                dataRowBuilder: (z) => [
                  TextButton.icon(
                    onPressed: () => selectedZone.value = z,
                    icon: const Icon(Icons.account_tree_outlined, size: 16),
                    label: Text(
                      z.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  _buildStatusChip(z.isActive, crmColors),
                  _buildActions(
                    onEdit: () => openZoneDialog(z),
                    onDelete: () async {
                      await ref.read(zoneServiceProvider).deleteZone(z.id);
                      ref.invalidate(zonesProvider);
                      ref.invalidate(paginatedZonesProvider);
                    },
                    crmColors: crmColors,
                  ),
                ],
                footer: PaginatedFooter(
                  page: res.page,
                  limit: res.limit,
                  totalPages: res.totalPages,
                  totalItems: res.totalItems,
                  currentItemCount: filteredItems.length,
                  onPrevious: res.page > 1 ? () => zonePage.value-- : null,
                  onNext: res.page < res.totalPages ? () => zonePage.value++ : null,
                ),
              );
            },
          );
        case 'States':
          return asyncStates.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading states: $err')),
            data: (res) {
              final filteredItems = searchQuery.value.isEmpty
                  ? res.items
                  : res.items.where((s) => s.name.toLowerCase().contains(searchQuery.value.toLowerCase())).toList();
              return _buildGeographicContent<GeographicState>(
                items: filteredItems,
                viewMode: viewMode.value,
                isMobile: isMobile,
                crmColors: crmColors,
                gridItemBuilder: (s) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildStatusChip(s.isActive, crmColors),
                          ],
                        ),
                        8.h,
                        Text(
                          'Zone: ${s.zoneName.isNotEmpty ? s.zoneName : 'None'}',
                          style: TextStyle(color: crmColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                headerRow: const ['Name', 'Zone', 'Status'],
                dataRowBuilder: (s) => [
                  Text(s.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(s.zoneName.isNotEmpty ? s.zoneName : 'None'),
                  _buildStatusChip(s.isActive, crmColors),
                ],
                footer: PaginatedFooter(
                  page: res.page,
                  limit: res.limit,
                  totalPages: res.totalPages,
                  totalItems: res.totalItems,
                  currentItemCount: filteredItems.length,
                  onPrevious: res.page > 1 ? () => statePage.value-- : null,
                  onNext: res.page < res.totalPages ? () => statePage.value++ : null,
                ),
              );
            },
          );
        case 'Regions':
          return asyncRegions.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading regions: $err')),
            data: (res) {
              final filteredItems = searchQuery.value.isEmpty
                  ? res.items
                  : res.items.where((r) => r.name.toLowerCase().contains(searchQuery.value.toLowerCase())).toList();
              return _buildGeographicContent<ServiceRegion>(
                items: filteredItems,
                viewMode: viewMode.value,
                isMobile: isMobile,
                crmColors: crmColors,
                gridItemBuilder: (r) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                r.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildStatusChip(r.isActive, crmColors),
                          ],
                        ),
                        8.h,
                        Text(
                          'State: ${r.stateName.isNotEmpty ? r.stateName : 'None'}',
                          style: TextStyle(color: crmColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                headerRow: const ['Name', 'State', 'Status'],
                dataRowBuilder: (r) => [
                  Text(r.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(r.stateName.isNotEmpty ? r.stateName : 'None'),
                  _buildStatusChip(r.isActive, crmColors),
                ],
                footer: PaginatedFooter(
                  page: res.page,
                  limit: res.limit,
                  totalPages: res.totalPages,
                  totalItems: res.totalItems,
                  currentItemCount: filteredItems.length,
                  onPrevious: res.page > 1 ? () => regionPage.value-- : null,
                  onNext: res.page < res.totalPages ? () => regionPage.value++ : null,
                ),
              );
            },
          );
        case 'Districts':
          return asyncDistricts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading districts: $err')),
            data: (res) {
              final filteredItems = searchQuery.value.isEmpty
                  ? res.items
                  : res.items.where((d) => d.name.toLowerCase().contains(searchQuery.value.toLowerCase())).toList();
              return _buildGeographicContent<District>(
                items: filteredItems,
                viewMode: viewMode.value,
                isMobile: isMobile,
                crmColors: crmColors,
                gridItemBuilder: (d) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                d.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildStatusChip(d.isActive, crmColors),
                          ],
                        ),
                        8.h,
                        Text(
                          'Region: ${d.regionName.isNotEmpty ? d.regionName : 'None'}',
                          style: TextStyle(color: crmColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                headerRow: const ['Name', 'Region', 'Status'],
                dataRowBuilder: (d) => [
                  Text(d.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(d.regionName.isNotEmpty ? d.regionName : 'None'),
                  _buildStatusChip(d.isActive, crmColors),
                ],
                footer: PaginatedFooter(
                  page: res.page,
                  limit: res.limit,
                  totalPages: res.totalPages,
                  totalItems: res.totalItems,
                  currentItemCount: filteredItems.length,
                  onPrevious: res.page > 1 ? () => districtPage.value-- : null,
                  onNext: res.page < res.totalPages ? () => districtPage.value++ : null,
                ),
              );
            },
          );
        case 'Pincodes':
          return asyncPincodes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading pincodes: $err')),
            data: (res) {
              final filteredItems = searchQuery.value.isEmpty
                  ? res.items
                  : res.items.where((p) => p.code.toLowerCase().contains(searchQuery.value.toLowerCase())).toList();
              return _buildGeographicContent<Pincode>(
                items: filteredItems,
                viewMode: viewMode.value,
                isMobile: isMobile,
                crmColors: crmColors,
                gridItemBuilder: (p) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                p.code,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildStatusChip(p.isActive, crmColors),
                          ],
                        ),
                        8.h,
                        Text(
                          'District: ${p.districtName.isNotEmpty ? p.districtName : 'None'}',
                          style: TextStyle(color: crmColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                headerRow: const ['Pincode', 'District', 'Status'],
                dataRowBuilder: (p) => [
                  Text(p.code, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(p.districtName.isNotEmpty ? p.districtName : 'None'),
                  _buildStatusChip(p.isActive, crmColors),
                ],
                footer: PaginatedFooter(
                  page: res.page,
                  limit: res.limit,
                  totalPages: res.totalPages,
                  totalItems: res.totalItems,
                  currentItemCount: filteredItems.length,
                  onPrevious: res.page > 1 ? () => pincodePage.value-- : null,
                  onNext: res.page < res.totalPages ? () => pincodePage.value++ : null,
                ),
              );
            },
          );
        default:
          return const SizedBox();
      }
    }

    IconData getCategoryIcon() {
      switch (category) {
        case 'Zones':
          return Icons.public_outlined;
        case 'States':
          return Icons.map_outlined;
        case 'Regions':
          return Icons.location_city_outlined;
        case 'Districts':
          return Icons.explore_outlined;
        case 'Pincodes':
          return Icons.pin_drop_outlined;
        default:
          return Icons.map;
      }
    }

    VoidCallback getCategoryAddDialog() {
      switch (category) {
        case 'Zones':
          return () => openZoneDialog();
        case 'States':
          return () => openStateDialog();
        case 'Regions':
          return () => openRegionDialog();
        case 'Districts':
          return () => openDistrictDialog();
        case 'Pincodes':
          return () => openPincodeDialog();
        default:
          return () {};
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildInnerHeader(
          title: '$category Management',
          icon: getCategoryIcon(),
          onAdd: getCategoryAddDialog(),
        ),
        buildSearchFilterBar(),
        Expanded(child: buildBody()),
      ],
    );
  }

  Widget _buildGeographicContent<T>({
    required List<T> items,
    required String viewMode,
    required bool isMobile,
    required CrmTheme crmColors,
    required Widget Function(T) gridItemBuilder,
    required List<String> headerRow,
    required List<Widget> Function(T) dataRowBuilder,
    required Widget footer,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
              16.h,
              const Text(
                'No records found. Click Add to create one.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (viewMode == 'grid') {
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 1 : 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isMobile ? 2.5 : 2.2,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => gridItemBuilder(items[index]),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: footer),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      // Header Row
                      TableRow(
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        children: headerRow
                            .map(
                              (h) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Text(
                                  h,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      // Data Rows
                      ...items.map((item) {
                        final cells = dataRowBuilder(item);
                        return TableRow(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                          children: cells
                              .map(
                                (cell) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: cell,
                                ),
                              )
                              .toList(),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(16), child: footer),
          ],
        );
      },
    );
  }

  Widget _buildCategoryCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required int count,
    required int activeCount,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$count',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Total',
                        style: TextStyle(
                          color: crmColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              4.h,
              Text(
                description,
                style: TextStyle(
                  color: crmColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Divider(color: theme.dividerColor.withValues(alpha: 0.05)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active: $activeCount  |  Inactive: ${count - activeCount}',
                    style: TextStyle(
                      color: crmColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: color,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneDetailsView({
    required BuildContext context,
    required ZoneModel zone,
    required List<GeographicState> states,
    required List<ServiceRegion> regions,
    required List<District> districts,
    required List<Pincode> pincodes,
    required VoidCallback onBack,
    required CrmTheme crmColors,
    required ThemeData theme,
    required bool isMobile,
  }) {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-header with Zone Info and back button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Zones',
                ),
                8.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            zone.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          12.w,
                          _buildStatusChip(zone.isActive, crmColors),
                        ],
                      ),
                      4.h,
                      Text(
                        'Detailed hierarchy of geographic entities mapping to this zone.',
                        style: TextStyle(color: crmColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatBadge('States', states.length, Colors.indigo),
                _buildStatBadge('Regions', regions.length, Colors.teal),
                _buildStatBadge('Districts', districts.length, Colors.orange),
                _buildStatBadge('Pincodes', pincodes.length, Colors.red),
              ],
            ),
          ),
          16.h,
          
          // Tab bar for Children
          TabBar(
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: crmColors.textSecondary,
            indicatorColor: theme.colorScheme.primary,
            tabs: [
              Tab(text: 'States (${states.length})'),
              Tab(text: 'Regions (${regions.length})'),
              Tab(text: 'Districts (${districts.length})'),
              Tab(text: 'Pincodes (${pincodes.length})'),
            ],
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                _buildZoneChildList(
                  items: states,
                  emptyText: 'No states mapped to this zone.',
                  isMobile: isMobile,
                  theme: theme,
                  crmColors: crmColors,
                  itemBuilder: (s) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      4.h,
                      Text('Zone: ${zone.name}', style: TextStyle(color: crmColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                _buildZoneChildList(
                  items: regions,
                  emptyText: 'No regions mapped to this zone.',
                  isMobile: isMobile,
                  theme: theme,
                  crmColors: crmColors,
                  itemBuilder: (r) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      4.h,
                      Text('State: ${r.stateName}', style: TextStyle(color: crmColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                _buildZoneChildList(
                  items: districts,
                  emptyText: 'No districts mapped to this zone.',
                  isMobile: isMobile,
                  theme: theme,
                  crmColors: crmColors,
                  itemBuilder: (d) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      4.h,
                      Text('Region: ${d.regionName}', style: TextStyle(color: crmColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                _buildZoneChildList(
                  items: pincodes,
                  emptyText: 'No pincodes mapped to this zone.',
                  isMobile: isMobile,
                  theme: theme,
                  crmColors: crmColors,
                  itemBuilder: (p) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      4.h,
                      Text('District: ${p.districtName}', style: TextStyle(color: crmColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, int value, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneChildList<T>({
    required List<T> items,
    required String emptyText,
    required bool isMobile,
    required ThemeData theme,
    required CrmTheme crmColors,
    required Widget Function(T) itemBuilder,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyText,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isMobile ? 3.0 : 2.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isActive = item is GeographicState ? item.isActive :
                         item is ServiceRegion ? item.isActive :
                         item is District ? item.isActive :
                         item is Pincode ? item.isActive : true;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: itemBuilder(item)),
                _buildStatusChip(isActive, crmColors),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(bool isActive, CrmTheme crmColors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? crmColors.success.withValues(alpha: 0.1)
            : crmColors.destructive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: isActive ? crmColors.success : crmColors.destructive,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActions({
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required CrmTheme crmColors,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: onEdit),
        IconButton(
          icon: Icon(Icons.delete, size: 18, color: crmColors.destructive),
          onPressed: onDelete,
        ),
      ],
    );
  }
}
