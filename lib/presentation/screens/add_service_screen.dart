import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class AddServiceScreen extends HookWidget {
  const AddServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    final formKey = useMemoized(() => GlobalKey<FormState>());
    final serviceNameCtrl = useTextEditingController();
    final durationCtrl = useTextEditingController(text: '60');
    final priceCtrl = useTextEditingController(text: '0');
    final descriptionCtrl = useTextEditingController();

    final selectedCategory = useState<String?>('Hair Styling');
    final selectedStatus = useState<String?>('Active');
    final selectedPricingType = useState<String?>('Fixed Price');
    final bufferMinutes = useState<double>(15);

    const categories = [
      'Hair Styling',
      'Makeup & Bridal',
      'Spa & Massage',
      'Skin & Facial',
      'Grooming',
    ];

    const statuses = ['Active', 'Inactive'];
    const pricingTypes = ['Fixed Price', 'Starting From', 'Custom Quote'];

    String formatCurrency() {
      final value = double.tryParse(priceCtrl.text.trim()) ?? 0;
      return '₹ ${value.toStringAsFixed(0)}';
    }

    String formatDuration() {
      final minutes = int.tryParse(durationCtrl.text.trim()) ?? 0;
      if (minutes <= 0) return '0 min';
      if (minutes < 60) return '$minutes min';
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) return '$hours hr';
      return '$hours hr $remainingMinutes min';
    }

    void submitService() {
      if (!formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service saved successfully.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      context.go('/services');
    }

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
                'Add New Service',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          24.h,
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: crmColors.border),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 32),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Service Details',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        16.h,
                        TextFormField(
                          controller: serviceNameCtrl,
                          decoration: _inputDeco('Service Name', crmColors),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                        16.h,
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedCategory.value,
                                items: categories
                                    .map(
                                      (category) => DropdownMenuItem(
                                        value: category,
                                        child: Text(category),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    selectedCategory.value = value,
                                decoration: _inputDeco('Category', crmColors),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            16.w,
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedStatus.value,
                                items: statuses
                                    .map(
                                      (status) => DropdownMenuItem(
                                        value: status,
                                        child: Text(status),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    selectedStatus.value = value,
                                decoration: _inputDeco('Status', crmColors),
                              ),
                            ),
                          ],
                        ),
                        16.h,
                        TextFormField(
                          controller: descriptionCtrl,
                          minLines: 4,
                          maxLines: 5,
                          decoration: _inputDeco('Description', crmColors)
                              .copyWith(
                                alignLabelWithHint: true,
                                hintText:
                                    'Describe what is included in this service...',
                              ),
                        ),
                        32.h,
                        const Divider(),
                        16.h,
                        Text(
                          'Pricing & Scheduling',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        16.h,
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: durationCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _inputDeco(
                                  'Duration (minutes)',
                                  crmColors,
                                ),
                                validator: (value) {
                                  final minutes = int.tryParse(value ?? '');
                                  if (minutes == null || minutes <= 0) {
                                    return 'Enter valid minutes';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            16.w,
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedPricingType.value,
                                items: pricingTypes
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    selectedPricingType.value = value,
                                decoration: _inputDeco(
                                  'Pricing Type',
                                  crmColors,
                                ),
                              ),
                            ),
                          ],
                        ),
                        16.h,
                        TextFormField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _inputDeco(
                            'Price',
                            crmColors,
                          ).copyWith(prefixText: '₹ '),
                          validator: (value) {
                            final price = double.tryParse(value ?? '');
                            if (price == null || price < 0) {
                              return 'Enter valid price';
                            }
                            return null;
                          },
                        ),
                        20.h,
                        Text(
                          'Buffer Time (${bufferMinutes.value.round()} min)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Slider(
                          value: bufferMinutes.value,
                          min: 0,
                          max: 60,
                          divisions: 12,
                          activeColor: crmColors.primary,
                          onChanged: (value) => bufferMinutes.value = value,
                        ),
                        32.h,
                        Row(
                          children: [
                            Expanded(
                              child: _summaryBox(
                                label: 'CATEGORY',
                                value: selectedCategory.value ?? '-',
                                border: crmColors.border,
                                valueColor: crmColors.textPrimary,
                              ),
                            ),
                            16.w,
                            Expanded(
                              child: _summaryBox(
                                label: 'DURATION',
                                value: formatDuration(),
                                border: crmColors.border,
                                valueColor: const Color(0xFFD97706),
                              ),
                            ),
                            16.w,
                            Expanded(
                              child: _summaryBox(
                                label: 'PRICE',
                                value: formatCurrency(),
                                border: crmColors.border,
                                valueColor: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        24.h,
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: submitService,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Create Service',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          48.h,
        ],
      ),
    );
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
      fillColor: Colors.white,
    );
  }

  Widget _summaryBox({
    required String label,
    required String value,
    required Color border,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 1.1,
            ),
          ),
          4.h,
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
