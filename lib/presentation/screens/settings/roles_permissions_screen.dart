import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_permissions.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../core/utils/responsive_builder.dart';
import '../../../services/role_service.dart';

/// Settings → Roles & Permissions.
///
/// Lets an administrator choose which feature modules each role can reach.
/// Changes apply to a user the next time they sign in.
class RolesPermissionsScreen extends ConsumerStatefulWidget {
  const RolesPermissionsScreen({super.key});

  @override
  ConsumerState<RolesPermissionsScreen> createState() =>
      _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState
    extends ConsumerState<RolesPermissionsScreen> {
  String? _selectedRoleId;
  Set<String> _draft = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(rolesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load roles:\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: crm.textSecondary)),
        ),
      ),
      data: (roles) {
        if (roles.isEmpty) {
          return const Center(child: Text('No roles configured.'));
        }
        final selected = roles.firstWhere(
          (r) => r.id == _selectedRoleId,
          orElse: () => roles.first,
        );
        // Adopt the stored permissions whenever the selection changes.
        if (_selectedRoleId != selected.id) {
          _selectedRoleId = selected.id;
          _draft = selected.permissions.toSet();
        }

        final list = _roleList(roles, selected, crm);
        final editor = _editor(selected, crm, isMobile);

        return Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Roles & Permissions',
                            style: TextStyle(
                                fontSize: isMobile ? 22 : 28,
                                fontWeight: FontWeight.w800,
                                color: crm.textPrimary)),
                        4.h,
                        Text(
                          'Choose which features each role can access. Applies at next sign-in.',
                          style: TextStyle(
                              fontSize: 13, color: crm.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _createRole,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Role'),
                  ),
                ],
              ),
              20.h,
              Expanded(
                child: isMobile
                    ? ListView(children: [list, 16.h, editor])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The role list grows with every custom role, so it
                          // scrolls independently of the editor beside it.
                          SizedBox(
                            width: 260,
                            child: SingleChildScrollView(child: list),
                          ),
                          20.w,
                          Expanded(child: SingleChildScrollView(child: editor)),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roleList(
      List<AppRoleRecord> roles, AppRoleRecord selected, CrmTheme crm) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in roles)
            InkWell(
              onTap: () => setState(() {
                _selectedRoleId = r.id;
                _draft = r.permissions.toSet();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: r.id == selected.id
                      ? crm.primary.withValues(alpha: 0.07)
                      : null,
                  border: Border(
                    left: BorderSide(
                      color: r.id == selected.id
                          ? crm.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          2.h,
                          Text(
                            '${r.permissions.length} features · ${r.userCount} user${r.userCount == 1 ? '' : 's'}',
                            style: TextStyle(
                                fontSize: 11, color: crm.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (r.isSystem)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: crm.textSecondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('BUILT-IN',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: crm.textSecondary)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _editor(AppRoleRecord role, CrmTheme crm, bool isMobile) {
    final dirty = _draft.length != role.permissions.length ||
        !_draft.containsAll(role.permissions);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(role.label,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              if (!role.isSystem)
                IconButton(
                  tooltip: 'Delete role',
                  onPressed: () => _deleteRole(role),
                  icon: Icon(Icons.delete_outline, color: crm.destructive),
                ),
            ],
          ),
          4.h,
          Text('Role key: ${role.key}   ·   Lands on ${role.homeRoute}',
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          if (role.key == 'admin') ...[
            10.h,
            _note(crm,
                'Administrators always keep full access, including Settings.'),
          ],
          16.h,
          Row(
            children: [
              Text('FEATURES',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: crm.textSecondary)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(
                    () => _draft = kAppFeatures.map((f) => f.key).toSet()),
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: () => setState(() => _draft = {}),
                child: const Text('Clear'),
              ),
            ],
          ),
          8.h,
          GridView.count(
            crossAxisCount: isMobile ? 1 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: isMobile ? 5.2 : 4.6,
            children: [
              for (final f in kAppFeatures) _featureTile(f, crm),
            ],
          ),
          16.h,
          Row(
            children: [
              if (dirty)
                Text('Unsaved changes',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: crm.warning)),
              const Spacer(),
              if (dirty)
                TextButton(
                  onPressed: () =>
                      setState(() => _draft = role.permissions.toSet()),
                  child: const Text('Reset'),
                ),
              8.w,
              FilledButton.icon(
                onPressed: (!dirty || _saving) ? null : () => _save(role),
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureTile(AppFeature f, CrmTheme crm) {
    final on = _draft.contains(f.key);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        if (on) {
          _draft.remove(f.key);
        } else {
          _draft.add(f.key);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: on ? crm.primary.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: on ? crm.primary.withValues(alpha: 0.4) : crm.border),
        ),
        child: Row(
          children: [
            Checkbox(
              value: on,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => setState(() {
                if (on) {
                  _draft.remove(f.key);
                } else {
                  _draft.add(f.key);
                }
              }),
            ),
            Icon(f.icon,
                size: 16, color: on ? crm.primary : crm.textSecondary),
            8.w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(f.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(f.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _note(CrmTheme crm, String text) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: crm.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: crm.primary),
            8.w,
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 11.5, color: crm.textPrimary)),
            ),
          ],
        ),
      );

  Future<void> _save(AppRoleRecord role) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(roleServiceProvider)
          .updateRole(role.id, permissions: _draft.toList());
      ref.invalidate(rolesProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('${role.label} permissions updated.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createRole() async {
    final nameCtrl = TextEditingController();
    final homeCtrl = TextEditingController(text: '/');
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Role name',
                hintText: 'e.g. Regional Manager',
              ),
            ),
            12.h,
            TextField(
              controller: homeCtrl,
              decoration: const InputDecoration(
                labelText: 'Landing page after login',
                hintText: '/clients',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Create')),
        ],
      ),
    );

    final name = nameCtrl.text.trim();
    final home = homeCtrl.text.trim();
    nameCtrl.dispose();
    homeCtrl.dispose();
    if (created != true || name.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(roleServiceProvider).createRole(
            label: name,
            permissions: const [],
            homeRoute: home.isEmpty ? '/' : home,
          );
      ref.invalidate(rolesProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Role "$name" created — now pick its features.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Could not create role: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteRole(AppRoleRecord role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete role?'),
        content: Text(
            'Remove "${role.label}"? Users must be reassigned to another role first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(roleServiceProvider).deleteRole(role.id);
      setState(() => _selectedRoleId = null);
      ref.invalidate(rolesProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Role deleted.')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }
}
