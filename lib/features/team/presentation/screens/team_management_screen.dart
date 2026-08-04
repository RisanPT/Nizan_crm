import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/auth/access_control.dart';
import '../../../../core/extensions/space_extension.dart';
import '../../../../core/models/crm_user.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../services/role_service.dart';
import '../../../../services/user_service.dart';
import '../../../../services/employee_service.dart';

/// Scoped user-management screen for Department Heads.
///
/// Shows only users created by the currently logged-in Department Head
/// ([CrmUser.managedBy] == session.userId).  The "Add Member" dialog
/// restricts the role dropdown to [Access.creatableRoles].
///
/// Admin / Manager users are never routed here — they use SettingsScreen.
class TeamManagementScreen extends HookConsumerWidget {
  const TeamManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final access = Access.of(session);

    // All users — filtered client-side to those managed by this head.
    final asyncUsers = ref.watch(crmUsersProvider);

    final myTeam = asyncUsers.when(
      // Filter to users whose managedBy matches the current department head's ID.
      // Guard against null: managedBy is null for admin-created users and must
      // not accidentally match a blank userId string.
      data: (users) {
        final myId = session?.userId ?? '';
        final allowedRoles = access.creatableRoles;
        return myId.isEmpty
            ? <CrmUser>[]
            : users
                .where((u) =>
                    u.id != myId &&
                    (u.managedBy == myId || allowedRoles.contains(u.role)))
                .toList();
      },
      loading: () => <CrmUser>[],
      error: (e, _) => <CrmUser>[],
    );

    Future<void> openMemberDialog([CrmUser? user]) async {
      final nameCtrl = TextEditingController(text: user?.name ?? '');
      final emailCtrl = TextEditingController(text: user?.email ?? '');
      final passwordCtrl = TextEditingController();

      // Department Heads only create within their own department.
      final allowed = access.creatableRoles.toList();
      var selectedRole = user?.role ?? (allowed.isNotEmpty ? allowed.first : '');
      var active = user?.active ?? true;
      // Artist/driver logins MUST link to an Employee profile, otherwise their
      // assigned works never resolve (their screens filter by employeeId).
      var selEmployeeId = user?.employeeId ?? '';

      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(user == null ? 'Add Team Member' : 'Edit Team Member'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      16.h,
                      // Email
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (login) *',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      16.h,
                      // Password
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: user == null
                              ? 'Password *'
                              : 'New Password (leave blank to keep)',
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                      ),
                      16.h,
                      // Role — scoped to allowed subordinate roles
                      Consumer(
                        builder: (ctx, ref, _) {
                          final rolesAsync = ref.watch(rolesProvider);
                          final allRoles = rolesAsync.value ?? [];
                          final filtered = allowed.isEmpty
                              ? allRoles
                              : allRoles
                                  .where((r) => allowed.contains(r.key))
                                  .toList();

                          return DropdownButtonFormField<String>(
                            initialValue: filtered.any((r) => r.key == selectedRole)
                                ? selectedRole
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Role *',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            items: [
                              for (final r in filtered)
                                DropdownMenuItem(
                                  value: r.key,
                                  child: Text(r.label),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => selectedRole = v);
                            },
                          );
                        },
                      ),
                      16.h,
                      // Link to Employee profile — required for artist/driver so
                      // their assigned works resolve; optional for other roles.
                      Consumer(
                        builder: (ctx, ref, _) {
                          final needsLink = selectedRole == 'artist' ||
                              selectedRole == 'driver';
                          final asyncEmployees = ref.watch(employeesProvider);
                          final employees = asyncEmployees.value ?? [];
                          if (asyncEmployees.isLoading) {
                            return const LinearProgressIndicator();
                          }
                          final hasEmployee = employees.any((e) => e.id == selEmployeeId);
                          return DropdownButtonFormField<String>(
                            initialValue: (selEmployeeId.isEmpty || !hasEmployee)
                                ? ''
                                : selEmployeeId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: needsLink
                                  ? 'Link to Employee Profile *'
                                  : 'Link to Employee Profile (Optional)',
                              prefixIcon: const Icon(Icons.link_outlined),
                              helperText:
                                  'Connects this login to a staff profile so assigned works show up.',
                              helperMaxLines: 2,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Not linked'),
                              ),
                              for (final e in employees)
                                DropdownMenuItem(
                                  value: e.id,
                                  child: Text(
                                    '${e.name} (${e.artistRole})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => selEmployeeId = v ?? ''),
                          );
                        },
                      ),
                      16.h,
                      // Active toggle
                      SwitchListTile(
                        title: const Text('Account Active'),
                        subtitle: const Text('Inactive users cannot log in'),
                        value: active,
                        onChanged: (v) => setState(() => active = v),
                        secondary: const Icon(Icons.toggle_on_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final email = emailCtrl.text.trim();
                    final password = passwordCtrl.text;

                    if (name.isEmpty || email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Name and email are required')),
                      );
                      return;
                    }
                    if (user == null && password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Password is required for new users')),
                      );
                      return;
                    }
                    // Without an employee link, an artist/driver login can never
                    // see the works assigned to them — block it here.
                    if ((selectedRole == 'artist' || selectedRole == 'driver') &&
                        selEmployeeId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Link this login to an Employee profile so assigned works show up.'),
                        ),
                      );
                      return;
                    }

                    try {
                      final svc = ref.read(userServiceProvider);
                      if (user == null) {
                        await svc.createUser(
                          name: name,
                          email: email,
                          password: password,
                          role: selectedRole,
                          active: active,
                          employeeId:
                              selEmployeeId.isEmpty ? null : selEmployeeId,
                        );
                      } else {
                        await svc.updateUser(
                          id: user.id,
                          name: name,
                          email: email,
                          role: selectedRole,
                          active: active,
                          password: password.isNotEmpty ? password : null,
                          employeeId:
                              selEmployeeId.isEmpty ? null : selEmployeeId,
                        );
                      }
                      ref.invalidate(crmUsersProvider);
                      ref.invalidate(employeesProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(e
                                  .toString()
                                  .replaceFirst('Exception: ', ''))),
                        );
                      }
                    }
                  },
                  child: Text(user == null ? 'Add Member' : 'Save Changes'),
                ),
              ],
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Team'),
        backgroundColor: crm.sidebar,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          FilledButton.icon(
            onPressed: () => openMemberDialog(),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add Member'),
            style: FilledButton.styleFrom(
              backgroundColor: crm.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          16.w,
        ],
      ),
      body: asyncUsers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (_) {
          if (myTeam.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_outlined,
                      size: 64,
                      color: crm.secondary.withValues(alpha: 0.4)),
                  16.h,
                  Text(
                    'No team members yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: crm.secondary.withValues(alpha: 0.6)),
                  ),
                  8.h,
                  Text(
                    'Tap "Add Member" to create a new login for your team.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: crm.secondary.withValues(alpha: 0.5)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: myTeam.length,
            separatorBuilder: (context, index) => 8.h,
            itemBuilder: (context, i) {
              final user = myTeam[i];
              return _TeamMemberCard(
                user: user,
                crm: crm,
                theme: theme,
                onEdit: () => openMemberDialog(user),
                onToggleActive: () async {
                  try {
                    await ref.read(userServiceProvider).updateUser(
                          id: user.id,
                          name: user.name,
                          email: user.email,
                          role: user.role,
                          active: !user.active,
                        );
                    ref.invalidate(crmUsersProvider);
                    ref.invalidate(employeesProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({
    required this.user,
    required this.crm,
    required this.theme,
    required this.onEdit,
    required this.onToggleActive,
  });

  final CrmUser user;
  final CrmTheme crm;
  final ThemeData theme;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: crm.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: user.active
              ? crm.accent.withValues(alpha: 0.15)
              : crm.secondary.withValues(alpha: 0.15),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: user.active ? crm.accent : crm.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.name,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.email,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: crm.textSecondary),
            ),
            4.h,
            Row(
              children: [
                _RoleChip(role: user.role, crm: crm),
                8.w,
                if (!user.active)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Inactive',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'edit') onEdit();
            if (val == 'toggle') onToggleActive();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: ListTile(
                leading: Icon(user.active
                    ? Icons.person_off_outlined
                    : Icons.person_outlined),
                title: Text(user.active ? 'Deactivate' : 'Reactivate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role, required this.crm});
  final String role;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: crm.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: crm.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
