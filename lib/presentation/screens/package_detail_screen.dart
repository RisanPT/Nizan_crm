import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../services/package_service.dart';
import '../../services/zone_service.dart';
import '../../services/state_service.dart';
import '../../services/region_service.dart';
import '../../services/district_service.dart';
import '../../core/models/zone.dart';
import '../../core/models/geographic_state.dart';
import '../../core/models/service_region.dart';
import '../../core/models/district.dart';
import '../../core/models/service_package.dart';

class PackageDetailScreen extends HookConsumerWidget {
  final String packageId;

  const PackageDetailScreen({super.key, required this.packageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;

    // Watch all geographic data
    final asyncZones = ref.watch(zonesProvider);
    final asyncStates = ref.watch(statesProvider);
    final asyncRegions = ref.watch(regionsProvider);
    final asyncDistricts = ref.watch(districtsProvider);
    final asyncPackages = ref.watch(packagesProvider);

    final zones = asyncZones.value ?? const <ZoneModel>[];
    final states = asyncStates.value ?? const <GeographicState>[];
    final regions = asyncRegions.value ?? const <ServiceRegion>[];
    final districts = asyncDistricts.value ?? const <District>[];

    final package = asyncPackages.value?.cast<ServicePackage?>().firstWhere(
      (item) => item?.id == packageId,
      orElse: () => null,
    );

    // Filter states
    final searchQuery = useState('');
    final selectedZoneId = useState('');
    final selectedStateId = useState('');
    final selectedRegionId = useState('');
    final selectedDistrictId = useState('');

    final availableStates = states.where((s) => s.zoneId == selectedZoneId.value).toList();
    final availableRegions = regions.where((r) => r.stateId == selectedStateId.value).toList();
    final availableDistricts = districts.where((d) => d.regionId == selectedRegionId.value).toList();

    // Geographic helper resolver
    Map<String, String> resolveGeoHierarchy(String districtId) {
      final d = districts.cast<District?>().firstWhere((d) => d?.id == districtId, orElse: () => null);
      if (d == null) {
        return {
          'district': '',
          'region': '',
          'state': '',
          'zone': '',
          'districtId': '',
          'regionId': '',
          'stateId': '',
          'zoneId': '',
        };
      }

      final r = regions.cast<ServiceRegion?>().firstWhere((r) => r?.id == d.regionId, orElse: () => null);
      if (r == null) {
        return {
          'district': d.name,
          'region': '',
          'state': '',
          'zone': '',
          'districtId': d.id,
          'regionId': '',
          'stateId': '',
          'zoneId': '',
        };
      }

      final s = states.cast<GeographicState?>().firstWhere((s) => s?.id == r.stateId, orElse: () => null);
      if (s == null) {
        return {
          'district': d.name,
          'region': r.name,
          'state': '',
          'zone': '',
          'districtId': d.id,
          'regionId': r.id,
          'stateId': '',
          'zoneId': '',
        };
      }

      final z = zones.cast<ZoneModel?>().firstWhere((z) => z?.id == s.zoneId, orElse: () => null);
      return {
        'district': d.name,
        'region': r.name,
        'state': s.name,
        'zone': z?.name ?? '',
        'districtId': d.id,
        'regionId': r.id,
        'stateId': s.id,
        'zoneId': z?.id ?? '',
      };
    }

    if (asyncPackages.isLoading ||
        asyncZones.isLoading ||
        asyncStates.isLoading ||
        asyncRegions.isLoading ||
        asyncDistricts.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (package == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Package Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Package with ID "$packageId" not found.', style: TextStyle(color: crmColors.textSecondary)),
              16.h,
              ElevatedButton(
                onPressed: () => context.go('/services'),
                child: const Text('Back to Packages'),
              ),
            ],
          ),
        ),
      );
    }

    // Filter overrides based on inputs
    final filteredOverrides = package.districtPrices.where((override) {
      final geo = resolveGeoHierarchy(override.districtId);
      final query = searchQuery.value.toLowerCase();

      // Search Query filter
      if (query.isNotEmpty) {
        final matchesDistrict = geo['district']!.toLowerCase().contains(query);
        final matchesRegion = geo['region']!.toLowerCase().contains(query);
        final matchesState = geo['state']!.toLowerCase().contains(query);
        final matchesZone = geo['zone']!.toLowerCase().contains(query);
        if (!matchesDistrict && !matchesRegion && !matchesState && !matchesZone) {
          return false;
        }
      }

      // Zone filter
      if (selectedZoneId.value.isNotEmpty && geo['zoneId'] != selectedZoneId.value) {
        return false;
      }
      // State filter
      if (selectedStateId.value.isNotEmpty && geo['stateId'] != selectedStateId.value) {
        return false;
      }
      // Region filter
      if (selectedRegionId.value.isNotEmpty && geo['regionId'] != selectedRegionId.value) {
        return false;
      }
      // District filter
      if (selectedDistrictId.value.isNotEmpty && geo['districtId'] != selectedDistrictId.value) {
        return false;
      }

      return true;
    }).toList();

    // Inline dialog handlers for direct additions/updates
    Future<void> showAddOrEditOverrideDialog({DistrictPrice? existingOverride}) async {
      final isEdit = existingOverride != null;
      final dialogZoneId = ValueNotifier<String>(existingOverride != null ? (resolveGeoHierarchy(existingOverride.districtId)['zoneId'] ?? '') : '');
      final dialogStateId = ValueNotifier<String>(existingOverride != null ? (resolveGeoHierarchy(existingOverride.districtId)['stateId'] ?? '') : '');
      final dialogRegionId = ValueNotifier<String>(existingOverride != null ? (resolveGeoHierarchy(existingOverride.districtId)['regionId'] ?? '') : '');
      final dialogDistrictId = ValueNotifier<String>(existingOverride != null ? existingOverride.districtId : '');
      final priceController = TextEditingController(text: existingOverride != null ? existingOverride.price.toStringAsFixed(0) : '');

      final formKey = GlobalKey<FormState>();

      await showDialog(
        context: context,
        builder: (ctx) {
          return HookConsumer(
            builder: (context, ref, child) {
              final activeZones = ref.watch(zonesProvider).value ?? [];
              final activeStates = ref.watch(statesProvider).value ?? [];
              final activeRegions = ref.watch(regionsProvider).value ?? [];
              final activeDistricts = ref.watch(districtsProvider).value ?? [];

              return ValueListenableBuilder<String>(
                valueListenable: dialogZoneId,
                builder: (_, zoneIdVal, _) {
                  final filteredStates = activeStates.where((s) => s.zoneId == zoneIdVal).toList();
                  return ValueListenableBuilder<String>(
                    valueListenable: dialogStateId,
                    builder: (_, stateIdVal, _) {
                      final filteredRegions = activeRegions.where((r) => r.stateId == stateIdVal).toList();
                      return ValueListenableBuilder<String>(
                        valueListenable: dialogRegionId,
                        builder: (_, regionIdVal, _) {
                          final filteredDistricts = activeDistricts.where((d) => d.regionId == regionIdVal).toList();
                          return AlertDialog(
                            title: Text(isEdit ? 'Edit Price Override' : 'Add Price Override'),
                            content: Form(
                              key: formKey,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isEdit) ...[
                                      DropdownButtonFormField<String>(
                                        value: zoneIdVal.isEmpty ? null : zoneIdVal,
                                        decoration: const InputDecoration(labelText: 'Select Zone'),
                                        items: activeZones.map((z) => DropdownMenuItem(value: z.id, child: Text(z.name))).toList(),
                                        onChanged: (val) {
                                          dialogZoneId.value = val ?? '';
                                          dialogStateId.value = '';
                                          dialogRegionId.value = '';
                                          dialogDistrictId.value = '';
                                        },
                                        validator: (val) => val == null ? 'Required' : null,
                                      ),
                                      12.h,
                                      DropdownButtonFormField<String>(
                                        value: stateIdVal.isEmpty ? null : stateIdVal,
                                        decoration: const InputDecoration(labelText: 'Select State'),
                                        items: filteredStates.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                                        onChanged: zoneIdVal.isEmpty ? null : (val) {
                                          dialogStateId.value = val ?? '';
                                          dialogRegionId.value = '';
                                          dialogDistrictId.value = '';
                                        },
                                        validator: (val) => val == null ? 'Required' : null,
                                      ),
                                      12.h,
                                      DropdownButtonFormField<String>(
                                        value: regionIdVal.isEmpty ? null : regionIdVal,
                                        decoration: const InputDecoration(labelText: 'Select Region'),
                                        items: filteredRegions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                                        onChanged: stateIdVal.isEmpty ? null : (val) {
                                          dialogRegionId.value = val ?? '';
                                          dialogDistrictId.value = '';
                                        },
                                        validator: (val) => val == null ? 'Required' : null,
                                      ),
                                      12.h,
                                      DropdownButtonFormField<String>(
                                        value: dialogDistrictId.value.isEmpty ? null : dialogDistrictId.value,
                                        decoration: const InputDecoration(labelText: 'Select District'),
                                        items: filteredDistricts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                                        onChanged: regionIdVal.isEmpty ? null : (val) {
                                          dialogDistrictId.value = val ?? '';
                                        },
                                        validator: (val) => val == null ? 'Required' : null,
                                      ),
                                      12.h,
                                    ] else ...[
                                      Text(
                                        'District: ${existingOverride.districtName}',
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      16.h,
                                    ],
                                    TextFormField(
                                      controller: priceController,
                                      decoration: const InputDecoration(labelText: 'Override Price (₹)', prefixText: '₹ '),
                                      keyboardType: TextInputType.number,
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) return 'Enter price';
                                        if (double.tryParse(val) == null) return 'Enter valid number';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  if (formKey.currentState?.validate() != true) return;

                                  final finalDistrictId = dialogDistrictId.value;
                                  final double finalPrice = double.parse(priceController.text);

                                  final updatedList = List<DistrictPrice>.from(package.districtPrices);

                                  if (isEdit) {
                                    final index = updatedList.indexWhere((item) => item.districtId == finalDistrictId);
                                    if (index != -1) {
                                      updatedList[index] = DistrictPrice(
                                        districtId: finalDistrictId,
                                        districtName: existingOverride.districtName,
                                        price: finalPrice,
                                      );
                                    }
                                  } else {
                                    // Check duplicate
                                    if (updatedList.any((item) => item.districtId == finalDistrictId)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Override for this district already exists!')),
                                      );
                                      return;
                                    }
                                    final districtObj = activeDistricts.cast<District?>().firstWhere(
                                      (d) => d?.id == finalDistrictId,
                                      orElse: () => null,
                                    );
                                    if (districtObj == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Selected district not found!')),
                                      );
                                      return;
                                    }
                                    updatedList.add(DistrictPrice(
                                      districtId: finalDistrictId,
                                      districtName: districtObj.name,
                                      price: finalPrice,
                                    ));
                                  }

                                  try {
                                    await ref.read(packageServiceProvider).savePackage(
                                      id: package.id,
                                      name: package.name,
                                      price: package.price,
                                      advanceAmount: package.advanceAmount,
                                      description: package.description,
                                      regionPrices: package.regionPrices,
                                      districtPrices: updatedList,
                                    );
                                    ref.invalidate(packagesProvider);
                                    ref.invalidate(paginatedPackagesProvider);
                                    if (context.mounted) {
                                      Navigator.of(ctx).pop();
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to save: $e')),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    }

    Future<void> deleteOverride(String districtId) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Override'),
          content: const Text('Are you sure you want to delete this location price override?'),
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
        final updatedList = package.districtPrices.where((item) => item.districtId != districtId).toList();
        try {
          await ref.read(packageServiceProvider).savePackage(
            id: package.id,
            name: package.name,
            price: package.price,
            advanceAmount: package.advanceAmount,
            description: package.description,
            regionPrices: package.regionPrices,
            districtPrices: updatedList,
          );
          ref.invalidate(packagesProvider);
          ref.invalidate(paginatedPackagesProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete: $e')),
            );
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: crmColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Premium Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/services'),
                  ),
                  8.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.name,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          package.description.isEmpty ? 'No description' : package.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: crmColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/services/add?id=${package.id}'),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Basic Info'),
                  ),
                  12.w,
                  ElevatedButton.icon(
                    onPressed: () => showAddOrEditOverrideDialog(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Override'),
                  ),
                ],
              ),
              24.h,

              // 2. Metrics Info Row
              Row(
                children: [
                  Expanded(
                    child: _DetailMetricCard(
                      label: 'BASE PACKAGE PRICE',
                      value: '₹ ${package.price.toStringAsFixed(0)}',
                      color: crmColors.success,
                      icon: Icons.monetization_on_outlined,
                      crmColors: crmColors,
                    ),
                  ),
                  16.w,
                  Expanded(
                    child: _DetailMetricCard(
                      label: 'BOOKING ADVANCE',
                      value: '₹ ${package.advanceAmount.toStringAsFixed(0)}',
                      color: crmColors.primary,
                      icon: Icons.payment_outlined,
                      crmColors: crmColors,
                    ),
                  ),
                  16.w,
                  Expanded(
                    child: _DetailMetricCard(
                      label: 'TOTAL GEOGRAPHIC OVERRIDES',
                      value: '${package.districtPrices.length} Locations',
                      color: crmColors.warning,
                      icon: Icons.map_outlined,
                      crmColors: crmColors,
                    ),
                  ),
                ],
              ),
              24.h,

              // 3. Search and Filter Bar
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
                            'Search & Filter Geographic Prices',
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
                                hintText: 'Search by Zone, State, Region or District...',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) => searchQuery.value = val,
                            ),
                          ),
                          if (searchQuery.value.isNotEmpty ||
                              selectedZoneId.value.isNotEmpty ||
                              selectedStateId.value.isNotEmpty ||
                              selectedRegionId.value.isNotEmpty ||
                              selectedDistrictId.value.isNotEmpty) ...[
                            12.w,
                            TextButton.icon(
                              onPressed: () {
                                searchQuery.value = '';
                                selectedZoneId.value = '';
                                selectedStateId.value = '';
                                selectedRegionId.value = '';
                                selectedDistrictId.value = '';
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
                              value: selectedZoneId.value.isEmpty ? null : selectedZoneId.value,
                              decoration: const InputDecoration(labelText: 'Zone', isDense: true),
                              items: zones.map((z) => DropdownMenuItem(value: z.id, child: Text(z.name))).toList(),
                              onChanged: (val) {
                                selectedZoneId.value = val ?? '';
                                selectedStateId.value = '';
                                selectedRegionId.value = '';
                                selectedDistrictId.value = '';
                              },
                            ),
                          ),
                          12.w,
                          // State Filter
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedStateId.value.isEmpty ? null : selectedStateId.value,
                              decoration: const InputDecoration(labelText: 'State', isDense: true),
                              items: availableStates.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                              onChanged: selectedZoneId.value.isEmpty ? null : (val) {
                                selectedStateId.value = val ?? '';
                                selectedRegionId.value = '';
                                selectedDistrictId.value = '';
                              },
                            ),
                          ),
                          12.w,
                          // Region Filter
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedRegionId.value.isEmpty ? null : selectedRegionId.value,
                              decoration: const InputDecoration(labelText: 'Region', isDense: true),
                              items: availableRegions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                              onChanged: selectedStateId.value.isEmpty ? null : (val) {
                                selectedRegionId.value = val ?? '';
                                selectedDistrictId.value = '';
                              },
                            ),
                          ),
                          12.w,
                          // District Filter
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedDistrictId.value.isEmpty ? null : selectedDistrictId.value,
                              decoration: const InputDecoration(labelText: 'District', isDense: true),
                              items: availableDistricts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                              onChanged: selectedRegionId.value.isEmpty ? null : (val) {
                                selectedDistrictId.value = val ?? '';
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

              // 4. Results List / Table Grid
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: crmColors.border),
                  ),
                  child: filteredOverrides.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map_outlined, size: 48, color: crmColors.border),
                              16.h,
                              Text(
                                'No geographic overrides found matching the filters.',
                                style: TextStyle(color: crmColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Table Header Row
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: crmColors.secondary,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    flex: 4,
                                    child: Text(
                                      'GEOGRAPHIC LOCATION PATH (ZONE › STATE › REGION › DISTRICT)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      'DISTRICT ONLY',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 2,
                                    child: Text(
                                      'OVERRIDE PRICE',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                                    ),
                                  ),
                                  const SizedBox(width: 80, child: Text('')), // Actions column
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            // Table Body List
                            Expanded(
                              child: ListView.separated(
                                itemCount: filteredOverrides.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = filteredOverrides[index];
                                  final geo = resolveGeoHierarchy(item.districtId);
                                  final fullPath = '${geo['zone']} › ${geo['state']} › ${geo['region']} › ${geo['district']}';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    child: Row(
                                      children: [
                                        // 1. Full geographic path
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            fullPath,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        // 2. District ONLY highlight
                                        Expanded(
                                          flex: 2,
                                          child: Chip(
                                            label: Text(geo['district'] ?? ''),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                        // 3. Override Price Tag
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '₹ ${item.price.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              color: crmColors.success,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        // 4. Edit/Delete inline buttons
                                        SizedBox(
                                          width: 80,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 18),
                                                onPressed: () => showAddOrEditOverrideDialog(existingOverride: item),
                                                tooltip: 'Edit Override Price',
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.delete_outline, size: 18, color: crmColors.destructive),
                                                onPressed: () => deleteOverride(item.districtId),
                                                tooltip: 'Remove Override',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final CrmTheme crmColors;

  const _DetailMetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.crmColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          16.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: crmColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                6.h,
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: crmColors.textPrimary,
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
