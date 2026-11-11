import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/features/hr/shared/hr_person_picker.dart';
import 'package:nizan_crm/features/hr/assets/data/employee_asset_models.dart';
import 'package:nizan_crm/features/hr/assets/service/employee_asset_service.dart';
import 'package:nizan_crm/features/hr/assets/presentation/widgets/employee_asset_dialogs.dart';
import 'package:nizan_crm/features/hr/assets/presentation/widgets/employee_assets_panel.dart';

/// HR › Employee Assets — company property issued to staff (laptops, phones,
/// kits, uniforms, ID cards, SIMs) and whether it came back. The backend
/// scopes the list: HR sees everyone, department heads their department,
/// employees only their own items.
class HrAssetsScreen extends ConsumerStatefulWidget {
  const HrAssetsScreen({super.key});

  @override
  ConsumerState<HrAssetsScreen> createState() => _HrAssetsScreenState();
}

class _HrAssetsScreenState extends ConsumerState<HrAssetsScreen> {
  String _status = 'issued';
  String? _employeeId;
  String _category = 'all';

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final rowsAsync = ref.watch(employeeAssetsProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final people = (employeesAsync.asData?.value ?? const [])
        .where((e) => e.status == 'active')
        .map((e) => PickerItem(id: e.id, name: e.name, department: e.department ?? ''))
        .toList();

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kAssetMaroon,
        foregroundColor: const Color(0xFFF5F3EF),
        onPressed: () => showIssueEmployeeAssetDialog(context, ref, employeeId: _employeeId, people: people),
        icon: const Icon(Icons.add),
        label: const Text('Issue asset', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => invalidateEmployeeAssets(ref),
        child: rowsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => invalidateEmployeeAssets(ref))]),
          data: (all) {
            final issued = all.where((a) => a.status == 'issued').length;
            final returned = all.where((a) => a.status == 'returned').length;
            final lost = all.where((a) => a.status == 'lost').length;
            final rows = all.where((a) {
              if (_status != 'all' && a.status != _status) return false;
              if (_employeeId != null && _employeeId!.isNotEmpty && a.employeeId != _employeeId) return false;
              if (_category != 'all' && a.category != _category) return false;
              return true;
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
              children: [
                Text('Employee Assets',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 24, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.5)),
                const SizedBox(height: 3),
                Text('Laptops, phones, kits, uniforms, ID cards & SIMs issued to staff',
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('issued', 'Issued ($issued)'),
                    _chip('returned', 'Returned ($returned)'),
                    _chip('lost', 'Lost ($lost)'),
                    _chip('all', 'All (${all.length})'),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (ctx, c) {
                  final narrow = c.maxWidth < 600;
                  final picker = PersonPickerField(
                    label: 'Employee',
                    icon: Icons.person_search_outlined,
                    selectedId: _employeeId,
                    items: people,
                    allowNone: true,
                    noneLabel: 'All employees',
                    onChanged: (v) => setState(() => _employeeId = (v == null || v.isEmpty) ? null : v),
                  );
                  final cat = DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All categories')),
                      ...kEmployeeAssetCategories
                          .map((c) => DropdownMenuItem(value: c, child: Text(employeeAssetCategoryLabel(c)))),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? 'all'),
                  );
                  if (narrow) {
                    return Column(children: [picker, const SizedBox(height: 10), cat]);
                  }
                  return Row(children: [
                    Expanded(flex: 3, child: picker),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: cat),
                  ]);
                }),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: hrCardDecoration(crm),
                  child: rows.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text('No assets match these filters.',
                                style: TextStyle(fontSize: 13, color: crm.textSecondary)),
                          ),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < rows.length; i++) ...[
                              if (i > 0) Divider(height: 1, color: crm.border),
                              EmployeeAssetTile(asset: rows[i], showEmployee: true),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _chip(String key, String label) {
    final selected = _status == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: kAssetMaroon,
      labelStyle: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w600, fontSize: 12.5),
      onSelected: (_) => setState(() => _status = key),
    );
  }
}
