import 'package:flutter/material.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/auth/access_control.dart';
import '../../../../core/extensions/space_extension.dart';
import '../../../../core/models/crm_user.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../services/role_service.dart';
import '../../../../services/user_service.dart';
import '../../../../services/employee_service.dart';
import '../../../../core/models/employee.dart';
import '../../../../core/widgets/employee_picker.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

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
      error: (e, _) => <CrmUser>[], // body's .when shows the error state
    );

    Future<void> openMemberDialog([CrmUser? user]) async {
      final nameCtrl = TextEditingController(text: user?.name ?? '');
      final emailCtrl = TextEditingController(text: user?.email ?? '');
      final passwordCtrl = TextEditingController();
      final phoneCtrl = TextEditingController();
      var obscurePassword = true;

      // Department Heads only create within their own department.
      final allowed = access.creatableRoles.toList();
      var selectedRole = user?.role ?? (allowed.isNotEmpty ? allowed.first : '');
      var active = user?.active ?? true;
      // Artist/driver logins MUST link to an Employee profile, otherwise their
      // assigned works never resolve (their screens filter by employeeId).
      var selEmployeeId = user?.employeeId ?? '';
      var saving = false;

      InputDecoration fieldDeco({
        required String label,
        required IconData icon,
        Widget? suffixIcon,
        String? helperText,
      }) {
        return InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
          suffixIcon: suffixIcon,
          helperText: helperText,
          helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF7B1E3B), width: 1.5),
          ),
        );
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            final isMobile = MediaQuery.of(ctx).size.width < 600;
            Widget pair(Widget a, Widget b) => isMobile
                ? Column(children: [a, 12.h, b])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: a),
                      12.w,
                      Expanded(child: b),
                    ],
                  );

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 32,
                vertical: 24,
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCE4EC),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      user == null
                          ? Icons.person_add_alt_1
                          : Icons.manage_accounts_outlined,
                      size: 20,
                      color: const Color(0xFF7B1E3B),
                    ),
                  ),
                  14.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user == null ? 'Add Team Member' : 'Edit Member · ${user.name}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user == null
                              ? 'Create a team member and assign role, access and profile.'
                              : 'Update team member credentials, role and employee link.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF6B7280),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Account Information ─────────────────────────────
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 10),
                        child: Text(
                          'ACCOUNT INFORMATION',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      pair(
                        TextField(
                          controller: nameCtrl,
                          decoration: fieldDeco(
                            label: 'Full Name *',
                            icon: Icons.person_outline,
                          ),
                        ),
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: fieldDeco(
                            label: 'Email (login) *',
                            icon: Icons.email_outlined,
                          ),
                        ),
                      ),
                      12.h,
                      pair(
                        TextField(
                          controller: passwordCtrl,
                          obscureText: obscurePassword,
                          decoration: fieldDeco(
                            label: user == null
                                ? 'Password *'
                                : 'New Password (leave blank to keep)',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: const Color(0xFF9CA3AF),
                              ),
                              onPressed: () => setState(
                                () => obscurePassword = !obscurePassword,
                              ),
                            ),
                          ),
                        ),
                        TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: fieldDeco(
                            label: 'Phone number',
                            icon: Icons.phone_outlined,
                          ),
                        ),
                      ),
                      16.h,
                      // ── Role and team ───────────────────────────────────
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 10),
                        child: Text(
                          'ROLE AND TEAM',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      pair(
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
                              decoration: fieldDeco(
                                label: 'Role *',
                                icon: Icons.badge_outlined,
                                helperText: rolesAsync.isLoading
                                    ? 'Loading roles…'
                                    : '${filtered.length} roles available',
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
                        Consumer(
                          builder: (ctx, ref, _) {
                            final needsLink = selectedRole == 'artist' ||
                                selectedRole == 'driver';
                            final asyncEmployees = ref.watch(employeesProvider);
                            final employees = (asyncEmployees.value ?? [])
                                .where((e) => e.isActive || e.isTimeboxLinked || e.id == selEmployeeId)
                                .toList();
                            if (asyncEmployees.isLoading) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 24),
                                child: LinearProgressIndicator(),
                              );
                            }
                            return EmployeePickerField(
                              employees: employees,
                              selectedId: selEmployeeId.isEmpty ? null : selEmployeeId,
                              label: needsLink
                                  ? 'Employee profile *'
                                  : 'Employee profile (optional)',
                              icon: Icons.link_outlined,
                              allowUnassign: true,
                              onChanged: (e) => setState(
                                () => selEmployeeId = e?.id ?? '',
                              ),
                            );
                          },
                        ),
                      ),
                      16.h,

                      // ── Extra Access ────────────────────────────────────
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 10),
                        child: Text(
                          'EXTRA ACCESS',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => active = !active),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFF7B1E3B).withValues(alpha: 0.04)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active
                                  ? const Color(0xFF7B1E3B).withValues(alpha: 0.35)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 18,
                                color: active ? const Color(0xFF7B1E3B) : const Color(0xFF6B7280),
                              ),
                              10.w,
                              const Expanded(
                                child: Text(
                                  'Active (can log in)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                              Switch(
                                value: active,
                                activeThumbColor: const Color(0xFF7B1E3B),
                                activeTrackColor: const Color(0xFFFCE4EC),
                                onChanged: (v) => setState(() => active = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                      12.h,
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
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

                          setState(() => saving = true);
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
                            ref.refreshData.crmUsers();
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) {
                              setState(() => saving = false);
                              showErrorSnackBar(ctx, e);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B1E3B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(user == null ? 'Create Member' : 'Save Changes'),
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
        error: (e, _) => AppErrorView(
            error: e, onRetry: () => ref.invalidate(crmUsersProvider)),
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
                    ref.refreshData.crmUsers();
                  } catch (e) {
                    if (context.mounted) {
                      showErrorSnackBar(context, e);
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
