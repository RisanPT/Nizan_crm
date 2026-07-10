import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/models/vendor.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../core/utils/responsive_builder.dart';
import '../../../services/inventory_service.dart';
import 'inventory_widgets.dart';

class InventoryVendorsScreen extends ConsumerWidget {
  const InventoryVendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(vendorsProvider);

    return InvBody(
      isMobile: isMobile,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Failed to load vendors: $e',
                style: TextStyle(color: crm.textSecondary))),
        data: (vendors) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InvHeader(
              title: 'Vendors',
              subtitle: '${vendors.length} suppliers',
              actionLabel: 'Add Vendor',
              onAction: () => showVendorDialog(context, ref),
            ),
            16.h,
            Expanded(
              child: vendors.isEmpty
                  ? const InvEmpty(
                      icon: Icons.storefront_outlined,
                      title: 'No vendors yet',
                      subtitle: 'Add suppliers to pick them on purchases.')
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: vendors.length,
                      separatorBuilder: (_, _) => 10.h,
                      itemBuilder: (_, i) => _card(context, ref, crm, vendors[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, CrmTheme crm, Vendor v) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: crm.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.storefront_rounded, color: crm.primary, size: 22),
          ),
          12.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                if (v.subtitle.isNotEmpty) ...[
                  2.h,
                  Text(v.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ],
                if (v.address.isNotEmpty) ...[
                  2.h,
                  Text(v.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: crm.textSecondary),
            onSelected: (val) {
              if (val == 'edit') showVendorDialog(context, ref, vendor: v);
              if (val == 'delete') _confirmDelete(context, ref, v);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 8),
                    Text('Edit')
                  ])),
              PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete, size: 16, color: crm.destructive),
                    const SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: crm.destructive)),
                  ])),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Vendor v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete vendor?'),
        content: Text('Remove "${v.name}" from your vendor list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(inventoryServiceProvider).deleteVendor(v.id);
      ref.invalidate(vendorsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

/// Add / edit a vendor with its GST-invoice details.
Future<void> showVendorDialog(BuildContext context, WidgetRef ref,
    {Vendor? vendor}) async {
  final name = TextEditingController(text: vendor?.name ?? '');
  final gst = TextEditingController(text: vendor?.gstNumber ?? '');
  final phone = TextEditingController(text: vendor?.phone ?? '');
  final email = TextEditingController(text: vendor?.email ?? '');
  final address = TextEditingController(text: vendor?.address ?? '');
  final state = TextEditingController(text: vendor?.state ?? '');
  final stateCode = TextEditingController(text: vendor?.stateCode ?? '');
  final bankName = TextEditingController(text: vendor?.bankName ?? '');
  final bankAcc = TextEditingController(text: vendor?.bankAccount ?? '');
  final bankIfsc = TextEditingController(text: vendor?.bankIfsc ?? '');
  final notes = TextEditingController(text: vendor?.notes ?? '');
  var saving = false;

  Widget field(TextEditingController c, String label, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label),
        ),
      );

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(vendor == null ? 'Add Vendor' : 'Edit Vendor'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field(name, 'Vendor name *'),
                field(gst, 'GST number'),
                Row(children: [
                  Expanded(child: field(phone, 'Phone')),
                  const SizedBox(width: 12),
                  Expanded(child: field(email, 'Email')),
                ]),
                field(address, 'Address', maxLines: 2),
                Row(children: [
                  Expanded(child: field(state, 'State')),
                  const SizedBox(width: 12),
                  SizedBox(width: 110, child: field(stateCode, 'State code')),
                ]),
                field(bankName, 'Bank name'),
                Row(children: [
                  Expanded(child: field(bankAcc, 'Account no.')),
                  const SizedBox(width: 12),
                  Expanded(child: field(bankIfsc, 'IFSC')),
                ]),
                field(notes, 'Notes', maxLines: 2),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    if (name.text.trim().isEmpty) return;
                    setState(() => saving = true);
                    try {
                      await ref.read(inventoryServiceProvider).saveVendor(
                            Vendor(
                              id: vendor?.id ?? '',
                              name: name.text.trim(),
                              gstNumber: gst.text.trim(),
                              phone: phone.text.trim(),
                              email: email.text.trim(),
                              address: address.text.trim(),
                              state: state.text.trim(),
                              stateCode: stateCode.text.trim(),
                              bankName: bankName.text.trim(),
                              bankAccount: bankAcc.text.trim(),
                              bankIfsc: bankIfsc.text.trim(),
                              notes: notes.text.trim(),
                            ),
                          );
                      ref.invalidate(vendorsProvider);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (e) {
                      setState(() => saving = false);
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
