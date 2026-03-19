import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/service_package.dart';
import '../../core/models/service_region.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/package_service.dart';
import '../../services/region_service.dart';

class AddServiceScreen extends HookConsumerWidget {
  const AddServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncRegions = ref.watch(regionsProvider);
    final regions = asyncRegions.value ?? const <ServiceRegion>[];

    final formKey = useMemoized(() => GlobalKey<FormState>());
    final packageNameCtrl = useTextEditingController();
    final priceCtrl = useTextEditingController(text: '0');
    final advanceCtrl = useTextEditingController(text: '3000');
    final descriptionCtrl = useTextEditingController();
    final isSaving = useState(false);
    final regionPriceControllers = useMemoized(
      () => {for (final region in regions) region.id: TextEditingController()},
      [regions.map((region) => region.id).join(',')],
    );

    Future<void> submitPackage() async {
      if (!formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }

      isSaving.value = true;
      try {
        final regionPrices = regions
            .map((region) {
              final raw = regionPriceControllers[region.id]?.text.trim() ?? '';
              if (raw.isEmpty) return null;
              final parsed = double.tryParse(raw);
              if (parsed == null) return null;
              return RegionalPrice(
                regionId: region.id,
                regionName: region.name,
                price: parsed,
              );
            })
            .whereType<RegionalPrice>()
            .toList();

        await ref
            .read(packageServiceProvider)
            .savePackage(
              name: packageNameCtrl.text.trim(),
              price: double.parse(priceCtrl.text.trim()),
              advanceAmount: double.parse(advanceCtrl.text.trim()),
              description: descriptionCtrl.text.trim(),
              regionPrices: regionPrices,
            );

        ref.invalidate(packagesProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Package saved successfully.'),
              backgroundColor: Color(0xFF10B981),
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
      onSubmit: submitPackage,
    );

    final regionsCard = _RegionsCard(
      theme: theme,
      crmColors: crmColors,
      asyncRegions: asyncRegions,
      regions: regions,
      regionPriceControllers: regionPriceControllers,
      basePriceHint: priceCtrl.text,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              8.w,
              Text(
                'Create New Package',
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
            regionsCard,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: basicCard),
                24.w,
                Expanded(child: regionsCard),
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
                  child: Text(isSaving ? 'Saving...' : 'Save Package'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionsCard extends StatelessWidget {
  final ThemeData theme;
  final CrmTheme crmColors;
  final AsyncValue<List<ServiceRegion>> asyncRegions;
  final List<ServiceRegion> regions;
  final Map<String, TextEditingController> regionPriceControllers;
  final String basePriceHint;

  const _RegionsCard({
    required this.theme,
    required this.crmColors,
    required this.asyncRegions,
    required this.regions,
    required this.regionPriceControllers,
    required this.basePriceHint,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Regional Pricing Override',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            8.h,
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Leave blank to use the base price.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () => GoRouter.of(context).go('/services/regions'),
                  child: const Text('Manage Regions'),
                ),
              ],
            ),
            16.h,
            if (asyncRegions.isLoading)
              const Center(child: CircularProgressIndicator()),
            if (asyncRegions.hasError)
              Text(
                'Failed to load regions.',
                style: TextStyle(color: crmColors.warning),
              ),
            if (!asyncRegions.isLoading && regions.isEmpty)
              Text(
                'No active regions found.',
                style: TextStyle(color: crmColors.textSecondary),
              ),
            ...regions.map(
              (region) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        region.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextFormField(
                        controller: regionPriceControllers[region.id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDeco(
                          'Price',
                          crmColors,
                        ).copyWith(prefixText: '₹ ', hintText: basePriceHint),
                      ),
                    ),
                  ],
                ),
              ),
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
