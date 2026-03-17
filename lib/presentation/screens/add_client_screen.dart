import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Client',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          4.h,
          Text(
            'Enter client details below to create a new profile.',
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: crmColors.textSecondary,
                ),
          ),
          24.h,
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: 32.p,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PHOTO UPLOAD
                        Row(
                          children: [
                            Container(
                              height: 80,
                              width: 80,
                              decoration: BoxDecoration(
                                color: crmColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.add_a_photo_outlined, color: crmColors.textSecondary),
                            ),
                            16.w,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Client Photo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                Text('Upload a high-quality photo. Recommended size: 200x200px.', style: TextStyle(color: crmColors.textSecondary, fontSize: 12)),
                                8.h,
                                OutlinedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.upload, size: 16),
                                  label: const Text('Choose File'),
                                )
                              ],
                            )
                          ],
                        ),
                        32.h,

                        // FORM FIELDS
                        if (isMobile) ...[
                          _buildTextField('Full Name', 'e.g. Jane Doe'),
                          16.h,
                          _buildTextField('Phone Number', '+1 (555) 000-0000'),
                          16.h,
                          _buildTextField('Email Address', 'jane.doe@example.com'),
                          16.h,
                          _buildDropdown('Gender', ['Female', 'Male', 'Other']),
                          16.h,
                          _buildTextField('Date of Birth', 'MM/DD/YYYY'),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(child: _buildTextField('Full Name', 'e.g. Jane Doe')),
                              24.w,
                              Expanded(child: _buildTextField('Phone Number', '+1 (555) 000-0000')),
                            ],
                          ),
                          16.h,
                          Row(
                            children: [
                              Expanded(child: _buildTextField('Email Address', 'jane.doe@example.com')),
                              24.w,
                              Expanded(child: _buildDropdown('Gender', ['Female', 'Male', 'Other'])),
                            ],
                          ),
                          16.h,
                          Row(
                            children: [
                              Expanded(child: _buildTextField('Date of Birth', 'MM/DD/YYYY')),
                              24.w,
                              const Spacer(), // empty slot
                            ],
                          ),
                        ],
                        16.h,
                        _buildTextField('Address', 'Street address, City, State, Zip'),
                        16.h,
                        _buildTextField('Notes', 'Add any special preferences, allergies, or historical notes here...', maxLines: 4),
                        
                        32.h,
                        const Divider(),
                        16.h,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => context.pop(),
                              child: const Text('Cancel'),
                            ),
                            16.w,
                            ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  // Submit
                                  context.pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: crmColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Save Client'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        8.h,
        TextFormField(
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: context.crmColors.background,
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        8.h,
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            filled: true,
            fillColor: context.crmColors.background,
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          hint: const Text('Select...'),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) {},
        ),
      ],
    );
  }
}
