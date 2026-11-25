import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';
import 'package:nizan_crm/features/website/presentation/widgets/website_fields_dialog.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// Which CRM packages / add-ons the website shows, and their website text.
/// Name, price and advance come from Services → Packages and are read-only here.
/// Changes go live straight away.
class PackagesTab extends ConsumerStatefulWidget {
  const PackagesTab({super.key});

  @override
  ConsumerState<PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends ConsumerState<PackagesTab> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(websitePackagesProvider);
      if (mounted) showSuccessSnackBar(context, success);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPackage(WebsiteSchema schema, WebsitePackage p) async {
    final fields = Map.of(schema.packageFields)..remove('show');
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WebsiteFieldsDialog(
        title: 'Website text — ${p.name}',
        subtitle:
            'Price ${_money.format(p.price)} and advance come from Services → Packages. '
            'Leave the description empty to use the CRM description.',
        fields: fields,
        initial: p.website,
        uploadSection: 'package',
        onSave: (data) =>
            ref.read(websiteServiceProvider).updatePackageWebsite(p.id, data),
      ),
    );
    if (saved == true) {
      ref.invalidate(websitePackagesProvider);
      if (mounted) {
        showSuccessSnackBar(
          context,
          'Saved. The website shows it within a minute.',
        );
      }
    }
  }

  Future<void> _editAddon(WebsiteSchema schema, WebsiteAddon a) async {
    final fields = Map.of(schema.addonFields)..remove('show');
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WebsiteFieldsDialog(
        title: 'Website text — ${a.name}',
        subtitle: 'Price ${_money.format(a.price)} comes from the CRM add-on.',
        fields: fields,
        initial: a.website,
        uploadSection: 'package',
        onSave: (data) =>
            ref.read(websiteServiceProvider).updateAddonWebsite(a.id, data),
      ),
    );
    if (saved == true) ref.invalidate(websitePackagesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final schemaAsync = ref.watch(websiteSchemaProvider);
    final dataAsync = ref.watch(websitePackagesProvider);

    return schemaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
        error: e,
        onRetry: () => ref.invalidate(websiteSchemaProvider),
      ),
      data: (schema) => dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
          error: e,
          onRetry: () => ref.invalidate(websitePackagesProvider),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            Text(
              'Packages',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: crm.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Switch on the packages the website should offer. Until at least one is on, '
              'the website shows its built-in package list.',
              style: TextStyle(fontSize: 12, color: crm.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final p in data.packages)
              _row(
                crm,
                title: p.name,
                subtitle: [
                  _money.format(p.price),
                  if ((p.website['tagline'] ?? '').toString().isNotEmpty)
                    p.website['tagline'],
                  if (p.website['highlighted'] == true) 'Most popular',
                ].join(' · '),
                show: p.show,
                onShow: (v) => _act(
                  () => ref.read(websiteServiceProvider).updatePackageWebsite(
                    p.id,
                    {'show': v},
                  ),
                  v
                      ? '${p.name} is now on the website.'
                      : '${p.name} is hidden from the website.',
                ),
                onEdit: () => _editPackage(schema, p),
              ),
            const SizedBox(height: 20),
            Text(
              'Add-ons',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: crm.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final a in data.addons)
              _row(
                crm,
                title: a.name,
                subtitle: a.isActive
                    ? _money.format(a.price)
                    : '${_money.format(a.price)} · inactive in CRM — never shown',
                show: a.show,
                onShow: a.isActive
                    ? (v) => _act(
                        () => ref
                            .read(websiteServiceProvider)
                            .updateAddonWebsite(a.id, {'show': v}),
                        v
                            ? '${a.name} is now on the website.'
                            : '${a.name} is hidden from the website.',
                      )
                    : null,
                onEdit: () => _editAddon(schema, a),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    CrmTheme crm, {
    required String title,
    required String subtitle,
    required bool show,
    required ValueChanged<bool>? onShow,
    required VoidCallback onEdit,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: crm.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: crm.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: crm.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit website text',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            Tooltip(
              message: show ? 'On the website' : 'Hidden from the website',
              child: Switch(value: show, onChanged: _busy ? null : onShow),
            ),
          ],
        ),
      ),
    );
  }
}
