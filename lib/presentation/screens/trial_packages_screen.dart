import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/trial_package.dart';
import '../../core/providers/trial_package_provider.dart';
import '../../core/theme/crm_theme.dart';

class TrialPackagesScreen extends ConsumerWidget {
  const TrialPackagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crmColors = context.crmColors;
    final asyncPackages = ref.watch(trialPackagesProvider);

    return Scaffold(
      backgroundColor: crmColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(context, ref),
        backgroundColor: crmColors.primary,
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        label: const Text('Add Package', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: asyncPackages.when(
        data: (packages) {
          if (packages.isEmpty) {
            return Center(
              child: Text(
                'No Trial Packages added yet.',
                style: TextStyle(color: crmColors.textSecondary),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: packages.length,
            itemBuilder: (context, index) {
              final pkg = packages[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: crmColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: crmColors.border),
                ),
                child: ListTile(
                  title: Text(
                    pkg.name,
                    style: TextStyle(
                      color: crmColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    pkg.description.isNotEmpty ? pkg.description : 'No description',
                    style: TextStyle(color: crmColors.textSecondary, fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${pkg.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: crmColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        color: crmColors.textSecondary,
                        onPressed: () => _showFormDialog(context, ref, pkg: pkg),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        color: crmColors.destructive,
                        onPressed: () => _confirmDelete(context, ref, pkg),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: crmColors.primary)),
        error: (error, stack) => Center(
          child: Text('Error: $error', style: TextStyle(color: crmColors.destructive)),
        ),
      ),
    );
  }

  void _showFormDialog(BuildContext context, WidgetRef ref, {TrialPackage? pkg}) {
    final crmColors = context.crmColors;
    final nameCtrl = TextEditingController(text: pkg?.name ?? '');
    final priceCtrl = TextEditingController(text: pkg != null ? pkg.price.toString() : '');
    final descCtrl = TextEditingController(text: pkg?.description ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: crmColors.surface,
              title: Text(
                pkg == null ? 'Add Trial Package' : 'Edit Trial Package',
                style: TextStyle(color: crmColors.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: crmColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Package Name',
                        labelStyle: TextStyle(color: crmColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: crmColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Price',
                        labelStyle: TextStyle(color: crmColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      style: TextStyle(color: crmColors.textPrimary),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        labelStyle: TextStyle(color: crmColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: crmColors.textSecondary)),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final price = double.tryParse(priceCtrl.text.trim());
                          if (name.isEmpty || price == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name and valid price are required')),
                            );
                            return;
                          }

                          setState(() => isSaving = true);
                          try {
                            final service = ref.read(trialPackageServiceProvider);
                            final newPkg = TrialPackage(
                              id: pkg?.id ?? '',
                              name: name,
                              price: price,
                              description: descCtrl.text.trim(),
                            );
                            if (pkg == null) {
                              await service.createTrialPackage(newPkg);
                            } else {
                              await service.updateTrialPackage(newPkg);
                            }
                            ref.invalidate(trialPackagesProvider);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                            setState(() => isSaving = false);
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: crmColors.primary),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(pkg == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, TrialPackage pkg) {
    final crmColors = context.crmColors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: crmColors.surface,
        title: Text('Delete Package?', style: TextStyle(color: crmColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete ${pkg.name}? This action cannot be undone.',
          style: TextStyle(color: crmColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: crmColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(trialPackageServiceProvider).deleteTrialPackage(pkg.id);
                ref.invalidate(trialPackagesProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting: $e')),
                  );
                }
              }
            },
            child: Text('Delete', style: TextStyle(color: crmColors.destructive)),
          ),
        ],
      ),
    );
  }
}
