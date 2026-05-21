import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/service_package.dart';
import '../../core/models/zone.dart';
import '../../core/models/geographic_state.dart';
import '../../core/models/service_region.dart';
import '../../core/models/district.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/package_service.dart';
import '../../services/zone_service.dart';
import '../../services/state_service.dart';
import '../../services/region_service.dart';
import '../../services/district_service.dart';

class AddServiceScreen extends HookConsumerWidget {
  final String? packageId;

  const AddServiceScreen({super.key, this.packageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncZones = ref.watch(zonesProvider);
    final asyncStates = ref.watch(statesProvider);
    final asyncRegions = ref.watch(regionsProvider);
    final asyncDistricts = ref.watch(districtsProvider);
    final asyncPackages = ref.watch(packagesProvider);

    final zones = asyncZones.value ?? const <ZoneModel>[];
    final states = asyncStates.value ?? const <GeographicState>[];
    final regions = asyncRegions.value ?? const <ServiceRegion>[];
    final districts = asyncDistricts.value ?? const <District>[];

    final existingPackage = asyncPackages.value?.cast<ServicePackage?>().firstWhere(
      (item) => item?.id == packageId,
      orElse: () => null,
    );

    final formKey = useMemoized(() => GlobalKey<FormState>());
    final packageNameCtrl = useTextEditingController();
    final priceCtrl = useTextEditingController(text: '0');
    final advanceCtrl = useTextEditingController(text: '3000');
    final descriptionCtrl = useTextEditingController();
    final isSaving = useState(false);
    final hasPrefilled = useState(false);

    final selectedZoneId = useState<String>('');
    final selectedStateId = useState<String>('');
    final selectedRegionId = useState<String>('');
    final selectedDistrictId = useState<String>('');
    final activeOverrideDistrictIds = useState<List<String>>([]);

    final districtPriceControllers = useMemoized(
      () => {for (final district in districts) district.id: TextEditingController()},
      [districts.map((district) => district.id).join(',')],
    );

    Future<void> handleBack() async {
      final didPop = await Navigator.of(context).maybePop();
      if (!didPop && context.mounted) {
        context.go('/services');
      }
    }

    useEffect(() {
      if (existingPackage == null || hasPrefilled.value) {
        return null;
      }

      packageNameCtrl.text = existingPackage.name;
      priceCtrl.text = existingPackage.price.toStringAsFixed(0);
      advanceCtrl.text = existingPackage.advanceAmount.toStringAsFixed(0);
      descriptionCtrl.text = existingPackage.description;

      for (final controller in districtPriceControllers.values) {
        controller.clear();
      }

      final prefilledIds = <String>[];
      for (final item in existingPackage.districtPrices) {
        districtPriceControllers[item.districtId]?.text = item.price.toStringAsFixed(
          0,
        );
        prefilledIds.add(item.districtId);
      }
      activeOverrideDistrictIds.value = prefilledIds;

      hasPrefilled.value = true;
      return null;
    }, [existingPackage, districtPriceControllers]);

    Future<void> submitPackage() async {
      if (!formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }

      isSaving.value = true;
      try {
        final districtPrices = activeOverrideDistrictIds.value
            .map((id) {
              final district = districts.cast<District?>().firstWhere(
                (d) => d?.id == id,
                orElse: () => null,
              );
              if (district == null) return null;
              final raw = districtPriceControllers[id]?.text.trim() ?? '';
              if (raw.isEmpty) return null;
              final parsed = double.tryParse(raw);
              if (parsed == null) return null;
              return DistrictPrice(
                districtId: district.id,
                districtName: district.name,
                price: parsed,
              );
            })
            .whereType<DistrictPrice>()
            .toList();

        await ref
            .read(packageServiceProvider)
            .savePackage(
              id: existingPackage?.id,
              name: packageNameCtrl.text.trim(),
              price: double.parse(priceCtrl.text.trim()),
              advanceAmount: double.parse(advanceCtrl.text.trim()),
              description: descriptionCtrl.text.trim(),
              regionPrices: const [],
              districtPrices: districtPrices,
            );

        ref.invalidate(packagesProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                existingPackage == null
                     ? 'Package saved successfully.'
                     : 'Package updated successfully.',
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          context.go('/services');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to save package: $e')));
        }
      } finally {
        isSaving.value = false;
      }
    }

    final basicCard = _BasicInfoCard(
      theme: theme,
      crmColors: crmColors,
      formKey: formKey,
      packageNameCtrl: packageNameCtrl,
      priceCtrl: priceCtrl,
      advanceCtrl: advanceCtrl,
      descriptionCtrl: descriptionCtrl,
      isSaving: isSaving.value,
      isEditing: existingPackage != null,
      onSubmit: submitPackage,
    );

    final districtsCard = _DistrictsCard(
      theme: theme,
      crmColors: crmColors,
      asyncZones: asyncZones,
      asyncStates: asyncStates,
      asyncRegions: asyncRegions,
      asyncDistricts: asyncDistricts,
      zones: zones,
      states: states,
      regions: regions,
      districts: districts,
      selectedZoneId: selectedZoneId,
      selectedStateId: selectedStateId,
      selectedRegionId: selectedRegionId,
      selectedDistrictId: selectedDistrictId,
      activeOverrideDistrictIds: activeOverrideDistrictIds,
      districtPriceControllers: districtPriceControllers,
      basePriceHint: priceCtrl.text,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: handleBack,
                icon: const Icon(Icons.arrow_back),
              ),
              8.w,
              Text(
                existingPackage == null ? 'Create New Package' : 'Edit Package',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          24.h,
          if (isMobile) ...[
            basicCard,
            24.h,
            districtsCard,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: basicCard),
                24.w,
                Expanded(child: districtsCard),
              ],
            ),
          48.h,
        ],
      ),
    );
  }
}

class _BasicInfoCard extends StatelessWidget {
  final ThemeData theme;
  final CrmTheme crmColors;
  final GlobalKey<FormState> formKey;
  final TextEditingController packageNameCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController advanceCtrl;
  final TextEditingController descriptionCtrl;
  final bool isSaving;
  final bool isEditing;
  final VoidCallback onSubmit;

  const _BasicInfoCard({
    required this.theme,
    required this.crmColors,
    required this.formKey,
    required this.packageNameCtrl,
    required this.priceCtrl,
    required this.advanceCtrl,
    required this.descriptionCtrl,
    required this.isSaving,
    required this.isEditing,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: crmColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Basic Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              16.h,
              TextFormField(
                controller: packageNameCtrl,
                decoration: _inputDeco('Package Name', crmColors),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              16.h,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDeco(
                        'Base Price',
                        crmColors,
                      ).copyWith(prefixText: '₹ '),
                      validator: _validateMoney,
                    ),
                  ),
                  16.w,
                  Expanded(
                    child: TextFormField(
                      controller: advanceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDeco(
                        'Advance Amount',
                        crmColors,
                      ).copyWith(prefixText: '₹ '),
                      validator: _validateMoney,
                    ),
                  ),
                ],
              ),
              16.h,
              TextFormField(
                controller: descriptionCtrl,
                minLines: 3,
                maxLines: 4,
                decoration: _inputDeco(
                  'Description',
                  crmColors,
                ).copyWith(alignLabelWithHint: true),
              ),
              24.h,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : onSubmit,
                  child: Text(
                    isSaving
                        ? (isEditing ? 'Updating...' : 'Saving...')
                        : (isEditing ? 'Update Package' : 'Save Package'),
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

class _DistrictsCard extends StatelessWidget {
  final ThemeData theme;
  final CrmTheme crmColors;
  final AsyncValue<List<ZoneModel>> asyncZones;
  final AsyncValue<List<GeographicState>> asyncStates;
  final AsyncValue<List<ServiceRegion>> asyncRegions;
  final AsyncValue<List<District>> asyncDistricts;
  final List<ZoneModel> zones;
  final List<GeographicState> states;
  final List<ServiceRegion> regions;
  final List<District> districts;
  final ValueNotifier<String> selectedZoneId;
  final ValueNotifier<String> selectedStateId;
  final ValueNotifier<String> selectedRegionId;
  final ValueNotifier<String> selectedDistrictId;
  final ValueNotifier<List<String>> activeOverrideDistrictIds;
  final Map<String, TextEditingController> districtPriceControllers;
  final String basePriceHint;

  const _DistrictsCard({
    required this.theme,
    required this.crmColors,
    required this.asyncZones,
    required this.asyncStates,
    required this.asyncRegions,
    required this.asyncDistricts,
    required this.zones,
    required this.states,
    required this.regions,
    required this.districts,
    required this.selectedZoneId,
    required this.selectedStateId,
    required this.selectedRegionId,
    required this.selectedDistrictId,
    required this.activeOverrideDistrictIds,
    required this.districtPriceControllers,
    required this.basePriceHint,
  });

  @override
  Widget build(BuildContext context) {
    final availableStates = states.where((s) => s.zoneId == selectedZoneId.value).toList();
    final availableRegions = regions.where((r) => r.stateId == selectedStateId.value).toList();
    final availableDistricts = districts.where((d) => d.regionId == selectedRegionId.value).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: crmColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'District Pricing Overrides',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            8.h,
            Text(
              'Select a district using the geographic hierarchy to add a price override.',
              style: TextStyle(color: crmColors.textSecondary, fontSize: 13),
            ),
            16.h,
            
            // 1. Zone Dropdown
            DropdownButtonFormField<String>(
              value: selectedZoneId.value.isEmpty ? null : selectedZoneId.value,
              decoration: _inputDeco('Select Zone', crmColors),
              items: zones.map((z) => DropdownMenuItem(value: z.id, child: Text(z.name))).toList(),
              onChanged: (val) {
                selectedZoneId.value = val ?? '';
                selectedStateId.value = '';
                selectedRegionId.value = '';
                selectedDistrictId.value = '';
              },
            ),
            12.h,

            // 2. State Dropdown
            DropdownButtonFormField<String>(
              value: selectedStateId.value.isEmpty ? null : selectedStateId.value,
              decoration: _inputDeco('Select State', crmColors),
              items: availableStates.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
              onChanged: selectedZoneId.value.isEmpty ? null : (val) {
                selectedStateId.value = val ?? '';
                selectedRegionId.value = '';
                selectedDistrictId.value = '';
              },
            ),
            12.h,

            // 3. Region Dropdown
            DropdownButtonFormField<String>(
              value: selectedRegionId.value.isEmpty ? null : selectedRegionId.value,
              decoration: _inputDeco('Select Region', crmColors),
              items: availableRegions.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
              onChanged: selectedStateId.value.isEmpty ? null : (val) {
                selectedRegionId.value = val ?? '';
                selectedDistrictId.value = '';
              },
            ),
            12.h,

            // 4. District Dropdown
            DropdownButtonFormField<String>(
              value: selectedDistrictId.value.isEmpty ? null : selectedDistrictId.value,
              decoration: _inputDeco('Select District', crmColors),
              items: availableDistricts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
              onChanged: selectedRegionId.value.isEmpty ? null : (val) {
                selectedDistrictId.value = val ?? '';
              },
            ),
            16.h,

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: selectedDistrictId.value.isEmpty
                    ? null
                    : () {
                        final districtId = selectedDistrictId.value;
                        if (!activeOverrideDistrictIds.value.contains(districtId)) {
                          activeOverrideDistrictIds.value = [
                            ...activeOverrideDistrictIds.value,
                            districtId,
                          ];
                        }
                        selectedDistrictId.value = '';
                      },
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add Price Override'),
              ),
            ),
            24.h,
            const Divider(),
            16.h,

            Text(
              'Active Pricing Overrides (${activeOverrideDistrictIds.value.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            12.h,

            if (activeOverrideDistrictIds.value.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No overrides added yet.\nAll districts will use the package base price.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: crmColors.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeOverrideDistrictIds.value.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final id = activeOverrideDistrictIds.value[index];
                  final district = districts.cast<District?>().firstWhere(
                    (d) => d?.id == id,
                    orElse: () => null,
                  );

                  if (district == null) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                district.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (district.regionName.isNotEmpty)
                                Text(
                                  district.regionName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: crmColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        12.w,
                        SizedBox(
                          width: 130,
                          child: TextFormField(
                            controller: districtPriceControllers[id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDeco(
                              'Price',
                              crmColors,
                            ).copyWith(prefixText: '₹ ', hintText: basePriceHint),
                          ),
                        ),
                        8.w,
                        IconButton(
                          onPressed: () {
                            activeOverrideDistrictIds.value = activeOverrideDistrictIds.value
                                .where((dId) => dId != id)
                                .toList();
                          },
                          icon: Icon(Icons.delete_outline, color: crmColors.destructive),
                          tooltip: 'Remove Override',
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

String? _validateMoney(String? value) {
  final parsed = double.tryParse(value ?? '');
  if (parsed == null || parsed < 0) {
    return 'Enter valid amount';
  }
  return null;
}

InputDecoration _inputDeco(String label, CrmTheme crmColors) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: crmColors.textSecondary, fontSize: 14),
    floatingLabelStyle: TextStyle(
      color: crmColors.primary,
      fontWeight: FontWeight.bold,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: crmColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: crmColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: crmColors.primary, width: 2),
    ),
    filled: true,
    fillColor: crmColors.surface,
  );
}
